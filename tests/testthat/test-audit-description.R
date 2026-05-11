# Regression tests for audit_description() (#52).
#
# CRAN policy: in the DESCRIPTION's `Description` field, package names
# (and software names in general) must appear in single quotes:
# "Wrapper around 'jsonlite' and 'httr' ...". An unquoted package
# name produces "Package names should be quoted in the Description
# field" on CRAN incoming pretest.
#
# audit_description() reads the Description field, tokenises it, and
# surfaces every word that matches an installed package name yet is
# not wrapped in single quotes. The detection is purely static: no
# package is loaded, no namespace is touched.

local_pkg_with_desc <- function(description, envir = parent.frame()) {
  path <- tempfile("pkg-desc-")
  dir.create(path)
  desc_lines <- c(
    "Package: dummy",
    "Title: Dummy package",
    "Version: 0.0.0.9000",
    "Authors@R: person('Test', 'User', email = 'a@b.c', role = c('aut', 'cre'))",
    paste0("Description: ", description),
    "License: MIT + file LICENSE",
    "Encoding: UTF-8"
  )
  writeLines(desc_lines, file.path(path, "DESCRIPTION"))
  withr::defer(unlink(path, recursive = TRUE), envir = envir)
  path
}

mock_installed <- c("jsonlite", "httr", "dplyr", "data.table", "rlang")

test_that("audit_description() flags unquoted package names", {
  pkg <- local_pkg_with_desc(
    "Wrapper around jsonlite and 'httr' for the dplyr ecosystem."
  )

  out <- suppressMessages(testthat::with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  ))

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("word", "position", "suggestion"))
  expect_setequal(out$word, c("jsonlite", "dplyr"))
  expect_true(all(grepl("'", out$suggestion, fixed = TRUE)))
})

test_that("audit_description() returns empty tibble when every match is quoted", {
  pkg <- local_pkg_with_desc(
    "Wrapper around 'jsonlite' and 'httr'."
  )

  out <- suppressMessages(testthat::with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  ))

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("word", "position", "suggestion"))
  expect_equal(nrow(out), 0L)
})

test_that("audit_description() does not flag words that are not package names", {
  pkg <- local_pkg_with_desc(
    "A toolkit for statistical analysis and reporting."
  )

  out <- suppressMessages(testthat::with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  ))

  expect_equal(nrow(out), 0L)
})

test_that("audit_description() handles a missing DESCRIPTION gracefully", {
  pkg <- tempfile("pkg-no-desc-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  expect_message(out <- audit_description(pkg), regexp = "DESCRIPTION")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
})

test_that("audit_description() handles a multi-line Description field", {
  desc <- paste(
    "Wrapper around jsonlite",
    "    and httr that exposes a dplyr-style API.",
    sep = "\n"
  )
  pkg <- local_pkg_with_desc(desc)

  out <- suppressMessages(testthat::with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  ))

  expect_setequal(out$word, c("jsonlite", "httr"))
})

test_that("audit_description() reports each occurrence even when the same package appears twice unquoted", {
  pkg <- local_pkg_with_desc(
    "Use jsonlite for parsing. The jsonlite output is then wrapped."
  )

  out <- suppressMessages(testthat::with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  ))

  expect_equal(nrow(out), 2L)
  expect_true(all(out$word == "jsonlite"))
  expect_equal(length(unique(out$position)), 2L)
})

test_that("audit_description() emits a cli summary message when hits are found", {
  pkg <- local_pkg_with_desc("Wrapper around jsonlite.")

  expect_message(
    testthat::with_mocked_bindings(
      audit_description(pkg),
      .installed_packages = function() {
        mock_installed
      },
      .package = "checkhelper"
    ),
    regexp = "unquoted package name"
  )
})

test_that("audit_description() flags package names that end a sentence (trailing dot)", {
  pkg <- local_pkg_with_desc("Wrapper around jsonlite.")

  out <- suppressMessages(testthat::with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  ))

  expect_equal(nrow(out), 1L)
  expect_equal(out$word, "jsonlite")
})

test_that("audit_description() does not flag the package's own name", {
  pkg <- tempfile("pkg-own-name-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  desc_lines <- c(
    "Package: jsonlite",
    "Title: Dummy",
    "Version: 0.0.0.9000",
    "Authors@R: person('A', 'B', email = 'a@b.c', role = c('aut', 'cre'))",
    "Description: jsonlite is a fast JSON parser.",
    "License: MIT + file LICENSE",
    "Encoding: UTF-8"
  )
  writeLines(desc_lines, file.path(pkg, "DESCRIPTION"))

  out <- suppressMessages(testthat::with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  ))

  expect_equal(nrow(out), 0L)
})

# --- Edge / coverage tests --------------------------------------------------

test_that("audit_description() warns when DESCRIPTION cannot be parsed", {
  pkg <- tempfile("pkg-bad-desc-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  # Garbage DESCRIPTION: a line without `Field:` triggers
  # "Line starting '...' is malformed!" inside read.dcf.
  writeLines(c("not a dcf file at all", "random garbage"), file.path(pkg, "DESCRIPTION"))

  expect_warning(
    out <- suppressMessages(audit_description(pkg)),
    regexp = "could not parse DESCRIPTION"
  )
  expect_equal(nrow(out), 0L)
})

test_that("audit_description() returns empty when DESCRIPTION has no Description field", {
  pkg <- tempfile("pkg-no-desc-field-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  writeLines(c("Package: x", "Title: t", "Version: 0.0.0"), file.path(pkg, "DESCRIPTION"))

  out <- suppressMessages(audit_description(pkg))
  expect_equal(nrow(out), 0L)
})

test_that("audit_description() returns empty when Description field is empty", {
  pkg <- tempfile("pkg-empty-desc-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  writeLines(
    c("Package: x", "Title: t", "Version: 0.0.0", "Description: "),
    file.path(pkg, "DESCRIPTION")
  )

  out <- suppressMessages(audit_description(pkg))
  expect_equal(nrow(out), 0L)
})

test_that("audit_description() handles DESCRIPTION without Package field (own_name = '')", {
  # Synthetic: read.dcf still returns a 1-row matrix without a Package column.
  pkg <- tempfile("pkg-no-package-field-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  writeLines(
    c("Title: t", "Description: Wrapper around jsonlite for parsing."),
    file.path(pkg, "DESCRIPTION")
  )

  out <- suppressMessages(testthat::with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() c("jsonlite"),
    .package = "checkhelper"
  ))
  expect_equal(out$word, "jsonlite")
})

test_that(".find_unquoted_pkg_names() returns empty on punctuation-only text", {
  empty <- checkhelper:::.find_unquoted_pkg_names(
    description = "...!!!",
    installed = c("jsonlite")
  )
  expect_equal(nrow(empty), 0L)
})

test_that(".find_unquoted_pkg_names() handles token at start and end of text", {
  # `jsonlite` at the very start (no `before` char) and `httr` at the very
  # end (no `after` char). Both must still be flagged.
  out <- checkhelper:::.find_unquoted_pkg_names(
    description = "jsonlite is faster than httr",
    installed = c("jsonlite", "httr")
  )
  expect_setequal(out$word, c("jsonlite", "httr"))
})

test_that(".installed_packages() returns the real catalogue when called unmocked", {
  out <- checkhelper:::.installed_packages()
  expect_true(is.character(out))
  expect_true(length(out) > 0L)
  # checkhelper itself must be installed during the test run.
  expect_true("checkhelper" %in% out || "testthat" %in% out)
})
