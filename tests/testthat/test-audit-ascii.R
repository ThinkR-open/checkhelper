test_that("audit_ascii() exists with the expected signature", {
  expect_true(is.function(audit_ascii))
  expect_named(
    formals(audit_ascii),
    c("pkg", "scope", "ignore_ext", "size_limit")
  )
})

test_that("audit_ascii() on an ASCII-clean fixture returns an empty data frame", {
  path <- suppressWarnings(create_example_pkg())
  on.exit(unlink(path, recursive = TRUE))
  out <- suppressMessages(audit_ascii(path))
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0L)
})

test_that("audit_ascii() flags non-ASCII bytes when present", {
  path <- suppressWarnings(create_example_pkg())
  on.exit(unlink(path, recursive = TRUE))
  writeLines(
    "x <- \"café\"",
    file.path(path, "R", "nonascii.R")
  )
  out <- suppressMessages(audit_ascii(path))
  expect_gt(nrow(out), 0L)
  expect_true("file" %in% colnames(out))
})

test_that("audit_ascii() emits a cli message", {
  path <- suppressWarnings(create_example_pkg())
  on.exit(unlink(path, recursive = TRUE))
  expect_message(audit_ascii(path), regexp = "ASCII|ascii")
})
