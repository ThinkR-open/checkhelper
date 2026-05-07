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
  out <- .check_clean_userspace(pkg = pkg, check_output = check_output)
  out <- tibble::as_tibble(out)

  n_leaks <- nrow(out)

  attr(out, "summary") <- sprintf(
    "%d file(s) leaked into user space", n_leaks
  )

  cli::cli_inform(c(
    "i" = "audit_userspace(): {n_leaks} file{?s} leaked into user space during checks."
  ))

  out
}


# Internal implementation ----------------------------------------------------

#' Verify the package's tests / examples / vignettes / full check leave
#' nothing behind in user space.
#'
#' @noRd
.check_clean_userspace <- function(pkg = ".", check_output = tempfile("dircheck")) {
  scratch_dir <- tempdir()

  # Set all three vars (Linux uses TMPDIR, macOS / Windows look at TMP /
  # TEMP). withr::local_envvar restores every var on exit even if the
  # function errors, which Sys.setenv + on.exit didn't (only TMPDIR was
  # being restored).
  withr::local_envvar(c(
    TMPDIR = scratch_dir,
    TMP    = scratch_dir,
    TEMP   = scratch_dir
  ))

  if (!dir.exists(scratch_dir)) {
    dir.create(scratch_dir)
  }
  if (!dir.exists(check_output)) {
    dir.create(check_output)
  }

  all_files <- tibble(
    source = character(0),
    problem = character(0),
    where = character(0),
    file = character(0)
  )

  local_tmpfile <- tempfile("local_shot")
  scratch_tmpfile <- tempfile("scratch_shot")
  local_shot <- utils::fileSnapshot(pkg, timestamp = local_tmpfile, md5sum = TRUE, recursive = TRUE, full.names = TRUE)
  scratch_shot <- utils::fileSnapshot(scratch_dir, timestamp = scratch_tmpfile, md5sum = TRUE, recursive = TRUE, full.names = TRUE)

  is.test <- list.files(file.path(pkg, "tests"))
  if (length(is.test) != 0) {
    cli::cli_rule("Unit tests")
    devtools::test(pkg = pkg, stop_on_failure = FALSE)
    all_files <- what_changed(local_shot, scratch_shot, source = "Unit tests", all_files, check_output = check_output)
  }

  local_shot <- utils::fileSnapshot(pkg, timestamp = local_tmpfile, md5sum = TRUE, recursive = TRUE, full.names = TRUE)
  scratch_shot <- utils::fileSnapshot(scratch_dir, timestamp = scratch_tmpfile, md5sum = TRUE, recursive = TRUE, full.names = TRUE)

  cli::cli_rule("Run examples")
  # fresh = TRUE spawns a non-interactive callr subprocess so examples
  # wrapped in `if (interactive())` are skipped exactly as they would be
  # under R CMD check (#87). With fresh = FALSE the call inherited the
  # parent session's `interactive()` value and ran example bodies the
  # user only meant to run in RStudio.
  examples_ok <- tryCatch(
    {
      devtools::run_examples(pkg = pkg, run_donttest = FALSE, run_dontrun = FALSE, fresh = TRUE, document = FALSE)
      TRUE
    },
    error = function(e) {
      warning(
        "Skipping the 'Run examples' step: devtools::run_examples() failed (",
        conditionMessage(e),
        "). The remaining steps (full check, vignettes) will still run.",
        call. = FALSE
      )
      FALSE
    }
  )
  # Always diff the snapshots, even on a partial run. Without this,
  # files created before the crash slipped into the next baseline and
  # became invisible to the rest of the audit. The source label is
  # tagged so the report distinguishes a clean run from a partial one.
  examples_source <- if (isTRUE(examples_ok)) {
    "Run examples"
  } else {
    "Run examples (partial)"
  }
  before_examples_rows <- nrow(all_files)
  all_files <- what_changed(local_shot, scratch_shot, source = examples_source, all_files, check_output)
  example_leaks <- all_files[
    seq.int(from = before_examples_rows + 1L, length.out = nrow(all_files) - before_examples_rows),
  ]
  if (nrow(example_leaks) > 0L) {
    warning(
      "Files surfaced during '", examples_source, "' (review whether each is a real leak or just a helper file):\n",
      paste0("  - ", example_leaks$file, collapse = "\n"),
      call. = FALSE
    )
  }

  local_shot <- utils::fileSnapshot(pkg, timestamp = local_tmpfile, md5sum = TRUE, recursive = TRUE, full.names = TRUE)
  scratch_shot <- utils::fileSnapshot(scratch_dir, timestamp = scratch_tmpfile, md5sum = TRUE, recursive = TRUE, full.names = TRUE)

  cli::cli_rule("Full check")
  rcmdcheck::rcmdcheck(path = pkg, check_dir = check_output, args = c("--no-manual", "--as-cran"), quiet = TRUE)
  all_files <- what_changed(local_shot, scratch_shot, source = "Full check", all_files, check_output)

  pkgname <- read.dcf(file.path(pkg, "DESCRIPTION"))[, "Package"]

  the_dir <- list.files(file.path(check_output), pattern = paste0(pkgname, ".Rcheck"), full.names = TRUE)
  still_files <- list.files(file.path(the_dir, "00_pkg_src", pkgname, "tests", "testthat"), full.names = TRUE)[
    !list.files(file.path(the_dir, "00_pkg_src", pkgname, "tests", "testthat")) %in%
      list.files(file.path(pkg, "tests", "testthat"))
  ]

  if (length(still_files) != 0) {
    all_files <- all_files %>%
      rbind(
        tibble(
          source = "Tests in check dir",
          problem = "added",
          where = the_dir,
          file = still_files
        )
      )

    message("Some files were still in tests/testthat dir after rcmdcheck: ", paste(still_files, collapse = ", "))
  }

  local_shot <- utils::fileSnapshot(pkg, timestamp = local_tmpfile, md5sum = TRUE, recursive = TRUE, full.names = TRUE)
  scratch_shot <- utils::fileSnapshot(scratch_dir, timestamp = scratch_tmpfile, md5sum = TRUE, recursive = TRUE, full.names = TRUE)

  cli::cli_rule("Build Vignettes")
  the_v <- devtools::build_vignettes(pkg = pkg)
  if (!all(is.null(the_v))) {
    devtools::clean_vignettes(pkg = pkg)
    all_files <- what_changed(local_shot, scratch_shot, source = "Build Vignettes", all_files, check_output)
  }

  return(all_files)
}

#' @noRd
what_changed <- function(local_shot, scratch_shot, source, all_files, check_output) {
  file.no.problem <- paste0(
    normalizePath(check_output, winslash = "/"),
    "|[.]Rcheck/|",
    normalizePath(file.path(tempdir(), "callr-"), winslash = "/", mustWork = FALSE),
    "|",
    normalizePath(file.path(tempdir(), "callr"), winslash = "/", mustWork = FALSE),
    "|",
    normalizePath(file.path(tempdir(), "test.*[.](o|c|so)$"), winslash = "/", mustWork = FALSE),
    "|",
    normalizePath(file.path(tempdir(), "foo[.]o$"), winslash = "/", mustWork = FALSE)
  )

  for (w.shot in c("local_shot", "scratch_shot")) {
    the_shot <- get(w.shot)
    all_local <- utils::changedFiles(the_shot, md5sum = TRUE, recursive = TRUE, full.names = TRUE)

    for (what in c("added", "deleted", "changed")) {
      if (length(all_local[[what]]) != 0) {
        all_local[[what]] <- normalizePath(all_local[[what]], winslash = "/")
        all_local[[what]] <- all_local[[what]][!grepl(file.no.problem, all_local[[what]])]
        if (length(all_local[[what]]) != 0) {
          all_files <- all_files %>%
            rbind(
              tibble(
                source = source,
                problem = what,
                where = the_shot$path,
                file = all_local[[what]]
              )
            )
          message(
            "Some files were ", what, " in ", the_shot$path, " after ", source, ": ",
            paste(all_local[[what]], collapse = ", ")
          )
        }
      }
    }
  }

  all_files
}
