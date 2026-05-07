# Regression tests for audit_citation() (#62).
#
# CRAN flags inst/CITATION files that still call the legacy forms:
#   - personList() / as.personList() (use c() on person() objects)
#   - citEntry() (use bibentry() instead)
# audit_citation() must surface every occurrence with line numbers and
# a suggested rewrite, while leaving modern files (c(person(...)) +
# bibentry()) untouched.

local_pkg_with_citation <- function(content, envir = parent.frame()) {
  path <- tempfile("pkg-cit-")
  dir.create(file.path(path, "inst"), recursive = TRUE)
  writeLines(content, file.path(path, "inst", "CITATION"))
  withr::defer(unlink(path, recursive = TRUE), envir = envir)
  path
}

test_that("audit_citation() flags personList(), as.personList() and citEntry()", {
  pkg <- local_pkg_with_citation(c(
    'citEntry(',
    '  entry  = "Manual",',
    '  title  = "My Package",',
    '  author = personList(',
    '    person("First", "Last", email = "a@b.org")',
    '  ),',
    '  year   = 2024,',
    '  note   = "R package"',
    ')'
  ))

  out <- audit_citation(pkg)

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("call", "line", "suggestion"))
  expect_setequal(out$call, c("citEntry", "personList"))
  expect_true(all(out$line >= 1L))
  expect_match(out$suggestion[out$call == "citEntry"], "bibentry", fixed = TRUE)
  expect_match(
    out$suggestion[out$call == "personList"],
    "c() on person()",
    fixed = TRUE
  )
})

test_that("audit_citation() flags as.personList() too", {
  pkg <- local_pkg_with_citation(c(
    'bibentry(',
    '  bibtype = "Manual",',
    '  title   = "Pkg",',
    '  author  = as.personList(person("A", "B")),',
    '  year    = 2025',
    ')'
  ))

  out <- audit_citation(pkg)

  expect_true("as.personList" %in% out$call)
})

test_that("audit_citation() returns an empty tibble when CITATION is modern", {
  pkg <- local_pkg_with_citation(c(
    'bibentry(',
    '  bibtype = "Manual",',
    '  title   = "Pkg",',
    '  author  = c(person("A", "B"), person("C", "D")),',
    '  year    = 2025,',
    '  note    = "R package"',
    ')'
  ))

  out <- audit_citation(pkg)

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("call", "line", "suggestion"))
  expect_equal(nrow(out), 0L)
})

test_that("audit_citation() handles a missing inst/CITATION gracefully", {
  pkg <- tempfile("pkg-no-cit-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  expect_message(out <- audit_citation(pkg), regexp = "no inst/CITATION")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
})

test_that("audit_citation() emits a cli summary message", {
  pkg <- local_pkg_with_citation('citEntry(entry = "Manual")')
  expect_message(audit_citation(pkg), regexp = "audit_citation")
})

test_that("audit_citation() reports correct line numbers for nested calls", {
  pkg <- local_pkg_with_citation(c(
    '# header comment',
    'citHeader("My pkg")',
    '',
    'citEntry(',
    '  entry = "Manual",',
    '  author = personList(person("A", "B"))',
    ')'
  ))

  out <- audit_citation(pkg)

  expect_true(any(out$call == "citEntry"))
  expect_true(any(out$call == "personList"))
  citEntry_line <- out$line[out$call == "citEntry"]
  personList_line <- out$line[out$call == "personList"]
  # citEntry( on its own line is line 4; personList nested inside.
  expect_true(citEntry_line == 4L)
  expect_true(personList_line >= 4L)
})
