#' Audit `inst/CITATION` for old-style calls flagged by CRAN
#'
#' Surfaces every call to `personList()`, `as.personList()` or
#' `citEntry()` in the package's `inst/CITATION` file, with the line
#' number and a one-line suggestion of the modern equivalent. CRAN
#' rejects new submissions whose CITATION file still uses these
#' (`Package CITATION file contains call(s) to old-style ...`).
#'
#' Detection is purely static (parse + token walk via
#' [utils::getParseData()]), so it does not source the file and never
#' executes user code.
#'
#' @param pkg Path to the package to audit.
#'
#' @return A tibble with columns `call`, `line`, `suggestion`. Empty
#'   when the file is modern, or when there is no `inst/CITATION`.
#' @export
#' @examples
#' \dontrun{
#' audit_citation(".")
#' }
audit_citation <- function(pkg = ".") {
  citation_path <- file.path(pkg, "inst", "CITATION")
  empty <- tibble::tibble(
    call = character(0),
    line = integer(0),
    suggestion = character(0)
  )

  if (!file.exists(citation_path)) {
    cli::cli_inform(c(
      "i" = "audit_citation(): no inst/CITATION file in {.path {pkg}}."
    ))
    return(empty)
  }

  out <- .find_old_citation_calls(citation_path)
  n <- nrow(out)
  if (n == 0L) {
    cli::cli_inform(c(
      "v" = "audit_citation(): no old-style calls detected."
    ))
  } else {
    cli::cli_inform(c(
      "i" = "audit_citation(): {n} old-style call{?s} found in inst/CITATION."
    ))
  }
  out
}

# Internal implementation ----------------------------------------------------

#' Map of legacy CITATION calls to their modern replacement guidance.
#' @noRd
.citation_legacy_calls <- c(
  citEntry        = "use bibentry() instead",
  personList      = "use c() on person() objects instead",
  `as.personList` = "use c() on person() objects instead"
)

#' Static parse of `inst/CITATION` collecting every legacy call site.
#'
#' Uses `parse(file, keep.source = TRUE)` + `utils::getParseData()` so
#' the file is never sourced; this avoids accidental side effects from
#' executing `inst/CITATION` at audit time. Returns a tibble with one
#' row per legacy call occurrence: nested calls
#' (e.g. `citEntry(author = personList(...))`) yield two rows.
#'
#' @noRd
.find_old_citation_calls <- function(path) {
  empty <- tibble::tibble(
    call = character(0),
    line = integer(0),
    suggestion = character(0)
  )
  # Surface a parse error as a warning rather than swallowing it
  # silently - otherwise a syntactically broken CITATION (missing
  # comma, unclosed paren, ...) would be reported as "no old-style
  # calls detected", which is misleading. Still return the empty
  # tibble so the caller can keep going.
  exprs <- tryCatch(
    parse(file = path, keep.source = TRUE),
    error = function(e) {
      warning(
        "Could not parse `", path, "`: ", conditionMessage(e),
        ". audit_citation() cannot inspect a syntactically broken file.",
        call. = FALSE
      )
      NULL
    }
  )
  if (is.null(exprs)) {
    return(empty)
  }
  parse_data <- utils::getParseData(exprs, includeText = TRUE)
  if (is.null(parse_data) || nrow(parse_data) == 0L) {
    return(empty)
  }

  legacy <- names(.citation_legacy_calls)
  hits <- parse_data[
    parse_data$token == "SYMBOL_FUNCTION_CALL" &
      parse_data$text %in% legacy,
    ,
    drop = FALSE
  ]
  if (nrow(hits) == 0L) {
    return(empty)
  }

  tibble::tibble(
    call = as.character(hits$text),
    line = as.integer(hits$line1),
    suggestion = unname(.citation_legacy_calls[hits$text])
  )
}
