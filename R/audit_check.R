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


# Internal implementation ----------------------------------------------------

#' Check the package with CRAN env vars and options.
#'
#' @noRd
.check_as_cran <- function(pkg = ".",
                           check_output = file.path(dirname(normalizePath(pkg, mustWork = FALSE)), "check"),
                           scratch = tempfile("scratch_dir"),
                           Ncpus = 1, as_command = FALSE,
                           clean_before = TRUE,
                           open = FALSE,
                           repos = getOption("repos")) {
  pkg <- normalizePath(pkg)

  prepare_check_dirs(
    check_output = check_output,
    scratch = scratch,
    clean_before = clean_before
  )

  if (is.null(repos) || identical(unname(repos), "@CRAN@") ||
        identical(unname(repos), character(0))) {
    repos <- c(CRAN = "https://cloud.r-project.org")
  }

  results <- withr::with_options(
    list(repos = repos),
    the_check(
      pkg = pkg,
      check_output = check_output,
      scratch = scratch,
      Ncpus = Ncpus,
      clean_before = clean_before
    )
  )

  writeLines("\nDepends:")
  tools::summarize_check_packages_in_dir_depends(check_output)
  writeLines("\nTimings:")
  tools::summarize_check_packages_in_dir_timings(check_output)
  writeLines("\nResults:")
  tools::summarize_check_packages_in_dir_results(check_output)
  writeLines("\nDetails:")
  tools::check_packages_in_dir_details(check_output)
  message("\nSee all check outputs in: ", check_output)

  if (isTRUE(open)) {
    utils::browseURL(check_output)
  }
  return(results)
}

#' Prepare the check_output and scratch directories used by .check_as_cran().
#' @noRd
prepare_check_dirs <- function(check_output, scratch, clean_before) {
  if (isTRUE(clean_before) | !dir.exists(check_output)) {
    if (dir.exists(check_output)) {
      unlink(check_output, recursive = TRUE)
    }
    dir.create(check_output, recursive = TRUE)
  }

  if (dir.exists(scratch)) {
    unlink(scratch, recursive = TRUE)
  }
  dir.create(scratch, recursive = TRUE)
}

#' @noRd
the_check <- function(pkg = ".", check_output, scratch, Ncpus = 1, as_command = FALSE, clean_before = TRUE) {
  pkgbuild::build(path = pkg, dest_path = check_output)

  envfile <- system.file("cran/CRAN_incoming/check.Renviron", package = "checkhelper")
  envfile_table <- utils::read.table(envfile, sep = "=")
  env_values <- as.list(t(envfile_table)[2, ])
  names(env_values) <- as.list(t(envfile_table)[1, ])

  lib_dir <- system.file("cran/lib", package = "checkhelper")

  withr::with_envvar(new = env_values, {
    if (!as_command) {
      Sys.setenv("TMPDIR" = scratch)
      cran_check_unique(check_output, lib_dir, scratch, Ncpus)
    } else {
      message("This may only run on Linux OS with sh")
      lib_bin <- system.file("cran/bin", package = "checkhelper")
    }
  })
}
