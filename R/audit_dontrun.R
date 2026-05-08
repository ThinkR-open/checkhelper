#' Audit `\dontrun{}` blocks across the package's Rd files
#'
#' Surfaces every `\dontrun{}` block in `man/*.Rd`, with the source
#' Rd file, the documented topic, the line number, and a one-line
#' suggestion of the modern equivalent. CRAN policy is that
#' `\dontrun{}` should only wrap example code that genuinely cannot
#' be executed (missing API key, missing system dependency, side
#' effect on the user's filespace). The contributor should otherwise
#' use `\donttest{}`, which still gets exercised by
#' `R CMD check --run-donttest` but is skipped by default.
#'
#' Detection is purely static: each Rd file is read line-by-line and
#' the literal `\dontrun{` opener is matched (commented-out forms
#' starting with `%` are ignored). The function never sources the
#' file and never executes user code.
#'
#' @param pkg Path to the package to audit.
#'
#' @return A tibble with columns `rd_file`, `topic`, `line`,
#'   `suggestion`. Empty when the package has no `\dontrun{}`
#'   blocks, or when there is no `man/` directory.
#' @export
#' @examples
#' \dontrun{
#' audit_dontrun(".")
#' }
audit_dontrun <- function(pkg = ".") {
  empty <- tibble::tibble(
    rd_file = character(0),
    topic = character(0),
    line = integer(0),
    suggestion = character(0)
  )

  man_dir <- file.path(pkg, "man")
  if (!dir.exists(man_dir)) {
    cli::cli_inform(c(
      "i" = "audit_dontrun(): no man/ directory in {.path {pkg}}."
    ))
    return(empty)
  }

  rd_files <- list.files(man_dir, pattern = "\\.Rd$", full.names = TRUE)
  if (length(rd_files) == 0L) {
    cli::cli_inform(c(
      "i" = "audit_dontrun(): no Rd files in {.path {man_dir}}."
    ))
    return(empty)
  }

  hits <- do.call(rbind, lapply(rd_files, .scan_one_rd_for_dontrun))
  if (is.null(hits) || nrow(hits) == 0L) {
    cli::cli_inform(c(
      "v" = "audit_dontrun(): no \\dontrun{{}} block detected."
    ))
    return(empty)
  }

  out <- tibble::as_tibble(hits)
  n <- nrow(out)
  cli::cli_inform(c(
    "i" = "audit_dontrun(): {n} `\\dontrun{{}}` block{?s} found across {length(unique(out$rd_file))} Rd file{?s}."
  ))
  out
}

# Internal implementation ----------------------------------------------------

#' Scan a single Rd file line-by-line and return a data.frame with one
#' row per `\dontrun{` opener. Commented-out forms (`% \dontrun{`)
#' are ignored.
#' @noRd
.scan_one_rd_for_dontrun <- function(rd_path) {
  lines <- tryCatch(
    readLines(rd_path, warn = FALSE),
    error = function(e) {
      warning(
        "Could not read `", rd_path, "`: ", conditionMessage(e),
        ". audit_dontrun() will skip this file.",
        call. = FALSE
      )
      character(0)
    }
  )
  if (length(lines) == 0L) {
    return(NULL)
  }

  is_hit <- grepl("\\\\dontrun\\{", lines, perl = TRUE) &
    !grepl("^[[:space:]]*%", lines, perl = TRUE)
  if (!any(is_hit)) {
    return(NULL)
  }

  data.frame(
    rd_file = basename(rd_path),
    topic = .topic_from_rd(lines, fallback = tools::file_path_sans_ext(basename(rd_path))),
    line = which(is_hit),
    suggestion = "consider replacing with \\donttest{} unless the example genuinely cannot be executed (missing API key / system dep / side effect)",
    stringsAsFactors = FALSE
  )
}

#' Pull the `\name{...}` value out of an Rd file's lines, falling
#' back to the file basename when the file has no `\name`.
#' @noRd
.topic_from_rd <- function(lines, fallback) {
  m <- regmatches(lines, regexpr("\\\\name\\{([^}]+)\\}", lines, perl = TRUE))
  m <- m[nzchar(m)]
  if (length(m) == 0L) {
    return(fallback)
  }
  sub("\\\\name\\{([^}]+)\\}", "\\1", m[1], perl = TRUE)
}
