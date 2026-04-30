test_that("audit_userspace() exists with the expected signature", {
  expect_true(is.function(audit_userspace))
  expect_named(formals(audit_userspace), c("pkg", "check_output"))
})

test_that("audit_userspace() emits a cli message (smoke)", {
  skip_on_cran()
  skip_on_ci()
  local_tempdir_clean()
  path <- suppressWarnings(create_example_pkg())
  on.exit(unlink(path, recursive = TRUE), add = TRUE)
  expect_message(
    suppressWarnings(audit_userspace(path)),
    regexp = "userspace|files|check"
  )
})

test_that("audit_userspace() returns a tibble with the documented columns + summary attr", {
  # Mocked path: the rcmdcheck-driven internal is replaced by a fake that
  # returns the same shape `.check_clean_userspace()` does. Verifies the
  # façade's contract (tibble + summary attr + cli line) without paying
  # the rcmdcheck cost. Runs on CI where the real path is skipped.
  fake <- data.frame(
    source  = c("Unit tests", "Run examples"),
    problem = c("added", "added"),
    where   = c("/tmp/x", "/tmp/y"),
    file    = c("a.R", "b.R"),
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(.check_clean_userspace = function(...) fake)

  out <- expect_message(
    audit_userspace("."),
    regexp = "2 files leaked"
  )
  expect_s3_class(out, "tbl_df")
  expect_named(out, c("source", "problem", "where", "file"))
  expect_equal(nrow(out), 2L)
  expect_match(attr(out, "summary"), "2 file\\(s\\) leaked")
})

test_that("audit_userspace() handles the no-leak case (0 files)", {
  fake <- data.frame(
    source = character(), problem = character(),
    where = character(), file = character(),
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(.check_clean_userspace = function(...) fake)

  out <- expect_message(audit_userspace("."), regexp = "0 files leaked")
  expect_equal(nrow(out), 0L)
})
