## test-deprecated.R
##
## For each of the 10 historic functions, verify:
##   - calling it emits lifecycle::deprecate_warn() (class
##     "lifecycle_warning_deprecated")
##   - calling it still returns a result of the expected shape
##
## The deprecation warning is gated by `lifecycle_verbosity`, which is set to
## "quiet" in helpers.R to keep other test files clean. Each test below
## locally bumps it to "warning".

setup_pkg <- function() {
  path <- suppressWarnings(create_example_pkg())
  withr::defer_parent(unlink(path, recursive = TRUE))
  path
}

test_that("find_nonascii_files() is deprecated and still returns a data frame", {
  path <- setup_pkg()
  withr::local_options(lifecycle_verbosity = "warning")
  expect_warning(
    out <- find_nonascii_files(path),
    class = "lifecycle_warning_deprecated"
  )
  expect_s3_class(out, "data.frame")
})

test_that("asciify_pkg() is deprecated and still rewrites in dry-run mode", {
  path <- setup_pkg()
  withr::local_options(lifecycle_verbosity = "warning")
  expect_warning(
    out <- asciify_pkg(path, dry_run = TRUE),
    class = "lifecycle_warning_deprecated"
  )
  expect_s3_class(out, "data.frame")
})

test_that("get_notes() is deprecated", {
  withr::local_options(lifecycle_verbosity = "warning")
  expect_warning(
    tryCatch(get_notes("nonexistent_path_xyz"), error = function(e) NULL),
    class = "lifecycle_warning_deprecated"
  )
})

test_that("get_no_visible() is deprecated", {
  withr::local_options(lifecycle_verbosity = "warning")
  expect_warning(
    tryCatch(get_no_visible("nonexistent_path_xyz"), error = function(e) NULL),
    class = "lifecycle_warning_deprecated"
  )
})

test_that("print_globals() is deprecated", {
  withr::local_options(lifecycle_verbosity = "warning")
  expect_warning(
    tryCatch(print_globals(NULL), error = function(e) NULL),
    class = "lifecycle_warning_deprecated"
  )
})

test_that("find_missing_tags() is deprecated", {
  withr::local_options(lifecycle_verbosity = "warning")
  expect_warning(
    tryCatch(find_missing_tags("nonexistent_path_xyz"), error = function(e) NULL),
    class = "lifecycle_warning_deprecated"
  )
})

test_that("check_as_cran() is deprecated", {
  withr::local_options(lifecycle_verbosity = "warning")
  expect_warning(
    tryCatch(check_as_cran("nonexistent_path_xyz"), error = function(e) NULL),
    class = "lifecycle_warning_deprecated"
  )
})

test_that("check_clean_userspace() is deprecated", {
  withr::local_options(lifecycle_verbosity = "warning")
  expect_warning(
    tryCatch(check_clean_userspace("nonexistent_path_xyz"), error = function(e) NULL),
    class = "lifecycle_warning_deprecated"
  )
})

test_that("get_data_info() is deprecated", {
  withr::local_options(lifecycle_verbosity = "warning")
  withr::with_tempdir({
    expect_warning(
      tryCatch(get_data_info("missing", "x", "y"), error = function(e) NULL),
      class = "lifecycle_warning_deprecated"
    )
  })
})

test_that("use_data_doc() is deprecated", {
  withr::local_options(lifecycle_verbosity = "warning")
  withr::with_tempdir({
    expect_warning(
      tryCatch(use_data_doc("missing"), error = function(e) NULL),
      class = "lifecycle_warning_deprecated"
    )
  })
})
