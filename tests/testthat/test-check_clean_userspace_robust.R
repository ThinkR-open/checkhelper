# Regression tests for #93: when devtools::run_examples() crashes deep in
# pkgload (`srcrefs[[1L]]: subscript out of bounds` on @examplesIf with an
# empty post-strip body, on older R + pkgload), check_clean_userspace()
# must not abort the whole audit — it must skip the examples step,
# surface a clear warning, and STILL run unit tests / full check /
# vignettes. Plus also call check_clean_userspace internal use the
# qualified path (checkhelper:::.check_clean_userspace) so the mock
# stays visible under R CMD check on the installed package.

test_that(".check_clean_userspace() survives a run_examples() crash and continues", {
  local_tempdir_clean()
  path <- suppressWarnings(create_example_pkg())
  suppressWarnings(attachment::att_amend_desc(path = path))

  # Counter env: each fake collaborator records that it was called so
  # the test can assert continuation (Copilot review on PR #104:
  # otherwise the test only proves that the function returns a tibble,
  # not that the rest of the pipeline ran).
  calls <- new.env(parent = emptyenv())
  calls$test <- 0L
  calls$rcmdcheck <- 0L
  calls$build_vignettes <- 0L
  calls$run_examples <- 0L

  fake_test <- function(...) {
    calls$test <- calls$test + 1L
    invisible(NULL)
  }
  fake_run_examples <- function(...) {
    calls$run_examples <- calls$run_examples + 1L
    stop("subscript out of bounds")
  }
  fake_rcmdcheck <- function(...) {
    calls$rcmdcheck <- calls$rcmdcheck + 1L
    list(notes = character(0), warnings = character(0), errors = character(0))
  }
  fake_build_vignettes <- function(...) {
    calls$build_vignettes <- calls$build_vignettes + 1L
    NULL
  }

  out <- suppressMessages(suppressWarnings(
    testthat::with_mocked_bindings(
      testthat::with_mocked_bindings(
        checkhelper:::.check_clean_userspace(pkg = path, check_output = tempfile("check_output")),
        rcmdcheck = fake_rcmdcheck,
        .package = "rcmdcheck"
      ),
      test = fake_test,
      run_examples = fake_run_examples,
      build_vignettes = fake_build_vignettes,
      .package = "devtools"
    )
  ))

  expect_s3_class(out, "tbl_df")
  expect_true(all(c("source", "problem", "where", "file") %in% names(out)))

  # The headline contract: every step downstream of the examples
  # crash must still have run.
  expect_gte(calls$run_examples, 1L)
  expect_gte(calls$rcmdcheck, 1L)
  expect_gte(calls$build_vignettes, 1L)

  # And the partial-run tag must surface in the report so the user
  # knows the examples slice was incomplete.
  expect_true(
    any(out$source == "Run examples (partial)") || nrow(out) == 0L,
    info = "either the partial tag is present, or the snapshot diff was empty"
  )

  unlink(path, recursive = TRUE)
})
