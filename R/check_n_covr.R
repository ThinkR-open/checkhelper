#' Run R CMD check and code coverage in one pass
#'
#' Splits the work between `devtools::check(args = "--no-tests")`
#' (the static / install / vignette parts of `R CMD check`) and
#' `covr::package_coverage(type = "tests")` (the test runner, with
#' coverage instrumentation). The unit tests run exactly once, on
#' the coverage side, instead of twice (once for the check, once
#' for the coverage). On a package with a slow suite this halves
#' the wait.
#'
#' @param pkg Path to the package.
#' @param args Character vector of extra args passed to
#'   `devtools::check()`. `--no-tests` is always prepended; pass
#'   `--as-cran`, `--no-manual` etc. here.
#' @param quiet Logical. Forwarded to both inner runners
#'   (`devtools::check(quiet = ...)` and
#'   `covr::package_coverage(quiet = ...)`). Default `TRUE`.
#'
#' @return A named list with two elements:
#'   * `check`: the `rcmdcheck` result returned by
#'     `devtools::check()`.
#'   * `coverage`: the `package_coverage` object returned by
#'     `covr::package_coverage()`.
#' @export
#' @examples
#' \dontrun{
#' res <- check_n_covr(".")
#' res$check
#' covr::percent_coverage(res$coverage)
#' }
check_n_covr <- function(pkg = ".", args = character(0), quiet = TRUE) {
  check <- .run_check_no_tests(
    pkg = pkg,
    args = c("--no-tests", args),
    quiet = quiet
  )
  coverage <- .run_coverage(pkg = pkg, type = "tests", quiet = quiet)

  pct <- .coverage_percent(coverage)
  cli::cli_inform(c(
    "i" = "check_n_covr(): {length(check$errors)} error{?s}, {length(check$warnings)} warning{?s}, {length(check$notes)} note{?s}; coverage {round(pct, 1)}%."
  ))

  list(check = check, coverage = coverage)
}

# Internal wrappers ---------------------------------------------------------

#' Run `devtools::check()` with the caller-supplied args. Wrapped so
#' tests can mock it via `testthat::with_mocked_bindings()`.
#' @noRd
.run_check_no_tests <- function(pkg, args, quiet) {
  devtools::check(pkg = pkg, args = args, quiet = quiet)
}

#' Run `covr::package_coverage()`. Wrapped so tests can mock it.
#' @noRd
.run_coverage <- function(pkg, type, quiet) {
  covr::package_coverage(path = pkg, type = type, quiet = quiet)
}

#' Compute the global percent coverage. Wrapped so tests can mock it
#' without depending on a real `package_coverage` object.
#' @noRd
.coverage_percent <- function(coverage) {
  covr::percent_coverage(coverage)
}
