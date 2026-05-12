# Regression tests for check_n_covr() (#67).
#
# check_n_covr() wires `devtools::check(args = "--no-tests")` to
# `covr::package_coverage(type = "tests")` so that the unit test
# suite runs exactly once (during the coverage pass) instead of
# twice. The tests below mock the two thin internal wrappers
# (.run_check_no_tests / .run_coverage) so the suite stays fast
# and side-effect free.

fake_check_result <- function(errors = character(0),
                              warnings = character(0),
                              notes = character(0)) {
  structure(
    list(errors = errors, warnings = warnings, notes = notes),
    class = "rcmdcheck"
  )
}

fake_coverage <- function(value = 87.5) {
  structure(list(.fake_pct = value), class = "package_coverage")
}

test_that("check_n_covr() returns a named list with check and coverage", {
  res <- testthat::with_mocked_bindings(
    suppressMessages(check_n_covr("/tmp/anywhere")),
    .run_check_no_tests = function(pkg, args, quiet) fake_check_result(),
    .run_coverage = function(pkg, type, quiet) fake_coverage(0),
    .coverage_percent = function(coverage) 0,
    .package = "checkhelper"
  )
  expect_named(res, c("check", "coverage"))
  expect_s3_class(res$check, "rcmdcheck")
  expect_s3_class(res$coverage, "package_coverage")
})

test_that("check_n_covr() prepends --no-tests to the args passed to the check runner", {
  captured <- list()
  testthat::with_mocked_bindings(
    suppressMessages(check_n_covr("/tmp/anywhere")),
    .run_check_no_tests = function(pkg, args, quiet) {
      captured$args <<- args
      fake_check_result()
    },
    .run_coverage = function(pkg, type, quiet) fake_coverage(0),
    .coverage_percent = function(coverage) 0,
    .package = "checkhelper"
  )
  expect_true("--no-tests" %in% captured$args)
  expect_equal(captured$args[1L], "--no-tests")
})

test_that("check_n_covr() passes user-supplied extra args through, with --no-tests in front", {
  captured <- list()
  testthat::with_mocked_bindings(
    suppressMessages(check_n_covr("/tmp/anywhere", args = c("--as-cran", "--no-manual"))),
    .run_check_no_tests = function(pkg, args, quiet) {
      captured$args <<- args
      fake_check_result()
    },
    .run_coverage = function(pkg, type, quiet) fake_coverage(0),
    .coverage_percent = function(coverage) 0,
    .package = "checkhelper"
  )
  expect_equal(captured$args, c("--no-tests", "--as-cran", "--no-manual"))
})

test_that("check_n_covr() calls covr::package_coverage() with type = 'tests'", {
  captured <- list()
  testthat::with_mocked_bindings(
    suppressMessages(check_n_covr("/tmp/anywhere")),
    .run_check_no_tests = function(pkg, args, quiet) fake_check_result(),
    .run_coverage = function(pkg, type, quiet) {
      captured$type <<- type
      captured$pkg <<- pkg
      fake_coverage(0)
    },
    .coverage_percent = function(coverage) 0,
    .package = "checkhelper"
  )
  expect_equal(captured$type, "tests")
  expect_equal(captured$pkg, "/tmp/anywhere")
})

test_that("check_n_covr() emits a cli summary mentioning errors / warnings / notes / coverage", {
  expect_message(
    testthat::with_mocked_bindings(
      check_n_covr("/tmp/anywhere"),
      .run_check_no_tests = function(pkg, args, quiet) {
        fake_check_result(notes = c("note 1", "note 2"))
      },
      .run_coverage = function(pkg, type, quiet) fake_coverage(91.4),
      .coverage_percent = function(coverage) 91.4,
      .package = "checkhelper"
    ),
    regexp = "check_n_covr.*note.*coverage"
  )
})

test_that("check_n_covr() forwards quiet = FALSE to both inner runners", {
  captured <- list()
  testthat::with_mocked_bindings(
    suppressMessages(check_n_covr("/tmp/anywhere", quiet = FALSE)),
    .run_check_no_tests = function(pkg, args, quiet) {
      captured$check_quiet <<- quiet
      fake_check_result()
    },
    .run_coverage = function(pkg, type, quiet) {
      captured$cov_quiet <<- quiet
      fake_coverage(0)
    },
    .coverage_percent = function(coverage) 0,
    .package = "checkhelper"
  )
  expect_false(captured$check_quiet)
  expect_false(captured$cov_quiet)
})
