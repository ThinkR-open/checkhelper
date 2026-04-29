test_that("fix_ascii() exists with the expected signature", {
  expect_true(is.function(fix_ascii))
  expect_named(
    formals(fix_ascii),
    c("pkg", "scope", "strategy", "identifiers", "dry_run")
  )
  expect_true(isTRUE(eval(formals(fix_ascii)$dry_run)))
})

test_that("fix_ascii(dry_run = TRUE) does not modify files", {
  path <- suppressWarnings(create_example_pkg())
  on.exit(unlink(path, recursive = TRUE))
  target <- file.path(path, "R", "nonascii.R")
  writeLines("x <- \"café\"", target)
  before <- readLines(target)
  suppressMessages(fix_ascii(path, dry_run = TRUE))
  after <- readLines(target)
  expect_equal(before, after)
})

test_that("fix_ascii(dry_run = FALSE) rewrites non-ASCII literals", {
  path <- suppressWarnings(create_example_pkg())
  on.exit(unlink(path, recursive = TRUE))
  target <- file.path(path, "R", "nonascii.R")
  writeLines("x <- \"café\"", target)
  suppressMessages(fix_ascii(path, dry_run = FALSE))
  after <- readLines(target)
  expect_true(all(!grepl("[^\x01-\x7f]", after, perl = TRUE)))
})

test_that("fix_ascii() emits a cli message", {
  path <- suppressWarnings(create_example_pkg())
  on.exit(unlink(path, recursive = TRUE))
  expect_message(fix_ascii(path, dry_run = TRUE), regexp = "ASCII|ascii")
})
