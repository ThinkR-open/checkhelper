test_that("check_as_cran() exposes a `repos` argument and a sensible default check_output (#79, #85)", {
  # We only assert on the formal API of the function — running an actual
  # CRAN-style check against a fake package is heavy and is already
  # covered (and flaky-skipped) by tests/testthat/test-check_as_cran.R.
  fmls <- formals(check_as_cran)
  expect_true("repos" %in% names(fmls), info = "should accept a `repos` argument (#79)")
  expect_true("check_output" %in% names(fmls))

  # check_output default should resolve to a directory adjacent to `pkg`,
  # not the session tempdir, so the user can find their logs (#85).
  default_out <- paste(deparse(fmls[["check_output"]]), collapse = " ")
  # We accept either dirname(pkg) or file.path(pkg, …) — anything that
  # references `pkg` works. The point is: not a session-only tempfile.
  expect_true(grepl("pkg", default_out, fixed = TRUE),
    info = "default check_output should reference the package path")
  expect_false(grepl("^tempfile", default_out),
    info = "default check_output should not be a session tempfile")
})

test_that("check_as_cran() falls back to cloud.r-project.org when repos is unset", {
  # Pin the fallback URL so the doc and the code can't drift apart again.
  # Read the function source rather than running the full check (heavy).
  src <- paste(deparse(check_as_cran), collapse = "\n")
  expect_true(
    grepl("cloud.r-project.org", src, fixed = TRUE),
    info = "fallback CRAN mirror should be cloud.r-project.org"
  )
})

test_that("prepare_check_dirs (re)creates scratch even when it already existed", {
  # Regression for the second-round review: when scratch existed, the
  # original code unlinked it without recreating it, so downstream steps
  # got an empty/missing TMPDIR.
  withr::with_tempdir({
    dir.create("co")
    dir.create("sc")

    # First call: scratch already exists -> must be recreated.
    checkhelper:::prepare_check_dirs(
      check_output = "co", scratch = "sc", clean_before = TRUE
    )
    expect_true(dir.exists("sc"))
    expect_true(dir.exists("co"))

    # Second call: scratch was deleted -> still must end up existing.
    unlink("sc", recursive = TRUE)
    checkhelper:::prepare_check_dirs(
      check_output = "co", scratch = "sc", clean_before = TRUE
    )
    expect_true(dir.exists("sc"))
  })
})
