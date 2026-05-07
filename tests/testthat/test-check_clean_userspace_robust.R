# Regression tests for #93: when devtools::run_examples() crashes deep in
# pkgload (`srcrefs[[1L]]: subscript out of bounds` on @examplesIf with an
# empty post-strip body, on older R + pkgload), check_clean_userspace()
# must not abort the whole audit — it must skip the examples step, surface
# a clear warning, and still run unit tests / full check / vignettes.

test_that(".check_clean_userspace() survives a run_examples() crash", {
  local_tempdir_clean()
  path <- suppressWarnings(create_example_pkg())
  suppressWarnings(attachment::att_amend_desc(path = path))

  fake_run_examples <- function(...) {
    stop("subscript out of bounds")
  }

  expect_warning(
    out <- testthat::with_mocked_bindings(
      .check_clean_userspace(pkg = path, check_output = tempfile("check_output")),
      run_examples = fake_run_examples,
      .package = "devtools"
    ),
    "examples"
  )

  expect_s3_class(out, "tbl_df")
  expect_true(all(c("source", "problem", "where", "file") %in% names(out)))

  unlink(path, recursive = TRUE)
})
