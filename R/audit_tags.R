#' Audit roxygen tags expected by CRAN
#'
#' Reports exported functions that lack `@return`, and documented internal
#' functions that lack `@noRd` (these trigger CRAN's
#' `Please add \value to .Rd files` message). Wraps [find_missing_tags()].
#'
#' @param pkg Path to the package to audit.
#'
#' @return A list with three tibbles: `package_doc`, `data`, `functions`.
#' @export
#' @seealso [find_missing_tags()]
#' @examples
#' \dontrun{
#' pkg <- create_example_pkg()
#' audit_tags(pkg)
#' }
audit_tags <- function(pkg = ".") {
  out <- find_missing_tags(package.dir = pkg)

  n_missing_return <- sum(out$functions$test_has_export_and_return == "not_ok")
  n_missing_nord <- sum(out$functions$test_has_export_or_has_nord == "not_ok")

  cli::cli_inform(c(
    "i" = "audit_tags(): {n_missing_return} missing @return tag{?s}, {n_missing_nord} missing @noRd tag{?s}."
  ))

  out
}
