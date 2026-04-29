#' Run R CMD check with CRAN environment
#'
#' Invokes `R CMD check` with the env vars and options used by CRAN's
#' incoming-pretest scripts, so local checks match CRAN as closely as
#' possible. Wraps [check_as_cran()].
#'
#' @param pkg Path to the package to check.
#' @param check_output Where to store check outputs.
#' @param scratch Where to store temporary files.
#' @param Ncpus Number of CPUs.
#' @param as_command Run as Linux command line instead of in R.
#' @param clean_before Wipe `check_output` before running.
#' @param open Open the check directory at the end.
#' @param repos Repositories used for dependency resolution.
#'
#' @return The `rcmdcheck` results object.
#' @export
#' @seealso [check_as_cran()].
#' @examples
#' \dontrun{
#' audit_check(".")
#' }
audit_check <- function(pkg = ".",
                        check_output = file.path(
                          dirname(normalizePath(pkg, mustWork = FALSE)),
                          "check"
                        ),
                        scratch = tempfile("scratch_dir"),
                        Ncpus = 1,
                        as_command = FALSE,
                        clean_before = TRUE,
                        open = FALSE,
                        repos = getOption("repos")) {
  out <- .check_as_cran(
    pkg = pkg,
    check_output = check_output,
    scratch = scratch,
    Ncpus = Ncpus,
    as_command = as_command,
    clean_before = clean_before,
    open = open,
    repos = repos
  )

  n_err <- length(out[["errors"]])
  n_warn <- length(out[["warnings"]])
  n_note <- length(out[["notes"]])

  cli::cli_inform(c(
    "i" = "audit_check(): {n_err} ERROR{?s}, {n_warn} WARNING{?s}, {n_note} NOTE{?s}."
  ))

  out
}
