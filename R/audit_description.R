#' Audit unquoted package names in DESCRIPTION's `Description` field
#'
#' CRAN policy: package names (and software names in general) inside
#' the `Description` field of a `DESCRIPTION` file must be wrapped in
#' single quotes (e.g. `'jsonlite'`, `'httr'`). An unquoted package
#' name produces the
#' `Package names should be quoted in the Description field`
#' warning on CRAN incoming pretest.
#'
#' `audit_description()` reads the `Description` field, tokenises it,
#' and surfaces every word that matches an installed package name yet
#' is not wrapped in single quotes. Detection is purely static: no
#' package is loaded, no namespace is touched.
#'
#' @param pkg Path to the package to audit.
#'
#' @return A tibble with columns `word`, `position` and `suggestion`.
#'   Empty when every match is already quoted, when the `Description`
#'   field is plain prose, or when the package has no `DESCRIPTION`.
#' @export
#' @examples
#' \dontrun{
#' audit_description(".")
#' }
audit_description <- function(pkg = ".") {
  empty <- tibble::tibble(
    word = character(0),
    position = integer(0),
    suggestion = character(0)
  )

  desc_path <- file.path(pkg, "DESCRIPTION")
  if (!file.exists(desc_path)) {
    cli::cli_inform(c(
      "i" = "audit_description(): no DESCRIPTION in {.path {pkg}}."
    ))
    return(empty)
  }

  dcf <- tryCatch(
    read.dcf(desc_path, fields = c("Package", "Description")),
    error = function(e) {
      cli::cli_warn(c(
        "x" = "audit_description(): could not parse DESCRIPTION: {conditionMessage(e)}."
      ))
      NULL
    }
  )
  if (is.null(dcf) || !"Description" %in% colnames(dcf)) {
    return(empty)
  }

  description <- as.character(dcf[1L, "Description"])
  own_name <- if ("Package" %in% colnames(dcf)) {
    as.character(dcf[1L, "Package"])
  } else {
    ""
  }
  if (is.na(description) || !nzchar(description)) {
    return(empty)
  }

  installed <- .installed_packages()
  hits <- .find_unquoted_pkg_names(
    description = description,
    installed = installed,
    own_name = own_name
  )

  if (nrow(hits) == 0L) {
    cli::cli_inform(c(
      "v" = "audit_description(): every package name in Description is quoted."
    ))
    return(empty)
  }

  cli::cli_inform(c(
    "i" = "audit_description(): {nrow(hits)} unquoted package name{?s} found in Description: {.val {unique(hits$word)}}."
  ))

  hits
}

# Internal implementation ----------------------------------------------------

#' Return the names of every package installed in the user's library.
#'
#' Wrapped so tests can mock the catalogue without paying the cost of
#' a real `installed.packages()` call (and without making the test
#' suite depend on whichever packages happen to be installed).
#' @noRd
.installed_packages <- function() {
  rownames(utils::installed.packages())
}

#' Tokenise the `Description` field and return a tibble of every
#' token that looks like an R package name but is not surrounded by
#' single quotes.
#'
#' A token is a maximal run of letters, digits and dots starting with
#' a letter. The token is considered quoted when the character
#' immediately before it is `'` and the character immediately after
#' it is `'`.
#' @noRd
.find_unquoted_pkg_names <- function(description, installed, own_name = "") {
  empty <- tibble::tibble(
    word = character(0),
    position = integer(0),
    suggestion = character(0)
  )

  text <- paste(description, collapse = " ")
  matches <- gregexpr("[A-Za-z][A-Za-z0-9.]*", text, perl = TRUE)[[1L]]
  if (length(matches) == 1L && matches[1L] == -1L) {
    return(empty)
  }

  starts <- as.integer(matches)
  lengths <- attr(matches, "match.length")
  ends <- starts + lengths - 1L

  chars <- strsplit(text, "", fixed = TRUE)[[1L]]
  total <- length(chars)

  records <- list()
  for (i in seq_along(starts)) {
    word <- substr(text, starts[i], ends[i])
    if (!word %in% installed) {
      next
    }
    if (nzchar(own_name) && identical(word, own_name)) {
      next
    }
    before <- if (starts[i] >= 2L) {
      chars[starts[i] - 1L]
    } else {
      ""
    }
    after <- if (ends[i] < total) {
      chars[ends[i] + 1L]
    } else {
      ""
    }
    is_quoted <- identical(before, "'") && identical(after, "'")
    if (is_quoted) {
      next
    }
    # Compound forms like `dplyr-style`, `httr2-based`, `foo_bar` are
    # not standalone package references. Only flag tokens that have a
    # whitespace or sentence-punctuation boundary on both sides.
    is_standalone <- grepl("^[[:space:]]*$|^[[:punct:]]$", before) &&
      grepl("^[[:space:]]*$|^[[:punct:]]$", after) &&
      !before %in% c("-", "_") &&
      !after %in% c("-", "_")
    if (!is_standalone) {
      next
    }
    records[[length(records) + 1L]] <- data.frame(
      word = word,
      position = starts[i],
      suggestion = paste0("wrap as '", word, "'"),
      stringsAsFactors = FALSE
    )
  }

  if (length(records) == 0L) {
    return(empty)
  }
  tibble::as_tibble(do.call(rbind, records))
}
