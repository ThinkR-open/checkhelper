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

  out <- with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  )

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("word", "position", "suggestion"))
  expect_setequal(out$word, c("jsonlite", "dplyr"))
  expect_true(all(grepl("'", out$suggestion, fixed = TRUE)))
})

test_that("audit_description() returns empty tibble when every match is quoted", {
  pkg <- local_pkg_with_desc(
    "Wrapper around 'jsonlite' and 'httr'."
  )

  out <- with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  )

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("word", "position", "suggestion"))
  expect_equal(nrow(out), 0L)
})

test_that("audit_description() does not flag words that are not package names", {
  pkg <- local_pkg_with_desc(
    "A toolkit for statistical analysis and reporting."
  )

  out <- with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  )

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

  out <- with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  )

  expect_setequal(out$word, c("jsonlite", "httr"))
})

test_that("audit_description() reports each occurrence even when the same package appears twice unquoted", {
  pkg <- local_pkg_with_desc(
    "Use jsonlite for parsing. The jsonlite output is then wrapped."
  )

  out <- with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  )

  expect_equal(nrow(out), 2L)
  expect_true(all(out$word == "jsonlite"))
  expect_equal(length(unique(out$position)), 2L)
})

test_that("audit_description() emits a cli summary message when hits are found", {
  pkg <- local_pkg_with_desc("Wrapper around jsonlite.")

  expect_message(
    with_mocked_bindings(
      audit_description(pkg),
      .installed_packages = function() {
        mock_installed
      },
      .package = "checkhelper"
    ),
    regexp = "audit_description"
  )
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

  out <- with_mocked_bindings(
    audit_description(pkg),
    .installed_packages = function() {
      mock_installed
    },
    .package = "checkhelper"
  )

  expect_equal(nrow(out), 0L)
})
