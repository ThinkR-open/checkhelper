test_that("fix_globals() exists with the expected signature", {
  expect_true(is.function(fix_globals))
  expect_named(formals(fix_globals), c("pkg", "write"))
  expect_false(eval(formals(fix_globals)$write))
})

test_that("fix_globals(write = FALSE) emits a message and does not modify R/globals.R", {
  skip_on_cran()
  local_tempdir_clean()
  path <- suppressWarnings(create_example_pkg())
  on.exit(unlink(path, recursive = TRUE), add = TRUE)
  globals_file <- file.path(path, "R", "globals.R")
  before_exists <- file.exists(globals_file)
  expect_message(suppressWarnings(fix_globals(path, write = FALSE)))
  after_exists <- file.exists(globals_file)
  expect_equal(before_exists, after_exists)
})
