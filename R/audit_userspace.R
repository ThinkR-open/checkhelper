#' Audit files left in user space by checks
#'
#' Runs the package's tests, examples, vignettes and full check, and lists
#' files that were created or modified outside the check directory. CRAN
#' raises a NOTE for "non-standard things in the check directory". Wraps
#' [check_clean_userspace()].
#'
#' @param pkg Path to the package to audit.
#' @param check_output Where to store check outputs (defaults to a tempfile).
#'
#' @return A tibble of leaked files with columns
#'   `source`, `problem`, `where`, `file`.
#' @export
#' @seealso [check_clean_userspace()].
#' @examples
#' \dontrun{
#' pkg <- create_example_pkg()
#' audit_userspace(pkg)
#' }
audit_userspace <- function(pkg = ".",
                            check_output = tempfile("dircheck")) {
  out <- check_clean_userspace(pkg = pkg, check_output = check_output)

  n_leaks <- nrow(out)

  cli::cli_inform(c(
    "i" = "audit_userspace(): {n_leaks} file{?s} leaked into user space during checks."
  ))

  out
}
