#' Audit globals to declare in R/globals.R
#'
#' Runs `R CMD check` on the package and extracts every
#' `no visible binding for global variable` and `no visible global function`
#' note. Use [fix_globals()] to print or write the corresponding
#' `globalVariables()` block. Wraps [get_no_visible()].
#'
#' @param pkg Path to the package to audit.
#'
#' @return A list with two tibbles, `globalVariables` and `functions`,
#'   or `NULL` if the package has no global notes.
#' @export
#' @seealso [fix_globals()], [get_no_visible()].
#' @examples
#' \dontrun{
#' pkg <- create_example_pkg()
#' audit_globals(pkg)
#' }
audit_globals <- function(pkg = ".") {
  out <- get_no_visible(path = pkg)

  if (is.null(out)) {
    cli::cli_inform(c("v" = "audit_globals(): no global notes detected."))
    return(out)
  }

  n_vars <- nrow(out[["globalVariables"]])
  n_funs <- nrow(out[["functions"]])

  cli::cli_inform(c(
    "i" = "audit_globals(): {n_vars} global variable{?s}, {n_funs} global function call{?s}."
  ))

  out
}

#' Print or write the globalVariables block to declare
#'
#' Convenience wrapper that runs the audit, then either prints the
#' `globalVariables(...)` block to console (default) or writes it to
#' `R/globals.R`. Wraps [print_globals()].
#'
#' @param pkg Path to the package.
#' @param write If `TRUE`, write/append to `<pkg>/R/globals.R`. Default `FALSE`.
#'
#' @return Invisibly, the path written (when `write = TRUE`) or `NULL`.
#' @export
#' @seealso [audit_globals()], [print_globals()].
#' @examples
#' \dontrun{
#' pkg <- create_example_pkg()
#' fix_globals(pkg)
#' fix_globals(pkg, write = TRUE)
#' }
fix_globals <- function(pkg = ".", write = FALSE) {
  globals <- get_no_visible(path = pkg)

  if (is.null(globals)) {
    cli::cli_inform(c("v" = "fix_globals(): no globals to declare."))
    return(invisible(NULL))
  }

  printed <- print_globals(globals = globals, message = FALSE)

  if (!isTRUE(write)) {
    message(printed[["liste_funs"]])
    message(printed[["liste_globals"]])
    cli::cli_inform(c(
      "i" = "fix_globals(): paste the block above into R/globals.R, or call fix_globals(write = TRUE)."
    ))
    return(invisible(NULL))
  }

  globals_path <- file.path(pkg, "R", "globals.R")
  if (!dir.exists(dirname(globals_path))) {
    dir.create(dirname(globals_path), recursive = TRUE)
  }

  writeLines(printed[["liste_globals"]], globals_path)
  cli::cli_inform(c(
    "v" = "fix_globals(): wrote globalVariables block to {.file {globals_path}}."
  ))

  invisible(globals_path)
}
