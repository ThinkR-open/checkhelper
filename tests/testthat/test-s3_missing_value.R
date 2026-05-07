# Regression tests for #92: find_missing_tags() / audit_tags() must report
# missing @return on S3 generics and on S3 methods that have their own Rd
# file (block carries a title / description). It must NOT flag methods
# whose block is just `@export` (no doc → no own Rd, just a NAMESPACE
# entry merged with the generic's Rd).

local_s3_pkg <- function(envir = parent.frame()) {
  path <- suppressWarnings(create_example_pkg())
  unlink(list.files(file.path(path, "R"), full.names = TRUE))
  unlink(list.files(file.path(path, "man"), full.names = TRUE))
  withr::defer(unlink(path, recursive = TRUE), envir = envir)
  path
}

test_that("S3 generic without @return is flagged as missing", {
  local_tempdir_clean()
  path <- local_s3_pkg()
  cat(
    "#' Convert strand to character",
    "#' @param strand strand",
    "#' @export",
    "strand_chr <- function(strand) {",
    "  UseMethod(\"strand_chr\")",
    "}",
    "",
    "#' @export",
    "strand_chr.character <- function(strand) {",
    "  strand",
    "}",
    sep = "\n",
    file = file.path(path, "R", "strand.R")
  )
  suppressWarnings(attachment::att_amend_desc(path = path))

  res <- suppressMessages(suppressWarnings(.find_missing_tags(package.dir = path)))

  flagged <- res$functions[res$functions$test_has_export_and_return == "not_ok", ]
  expect_true("strand_chr" %in% flagged$topic,
    info = "S3 generic without @return must be flagged"
  )
  # The bare `@export` method has no title/description and therefore
  # does not generate its own Rd file. CRAN won't ask for \value for it.
  expect_false("strand_chr.character" %in% flagged$topic,
    info = "Bare-@export S3 method must not be flagged"
  )
})

test_that("S3 method with its own doc but no @return is flagged", {
  local_tempdir_clean()
  path <- local_s3_pkg()
  cat(
    "#' Convert strand to character",
    "#' @param strand strand",
    "#' @return character",
    "#' @export",
    "strand_chr <- function(strand) {",
    "  UseMethod(\"strand_chr\")",
    "}",
    "",
    "#' Dim of a layout",
    "#'",
    "#' Returns the dimension of the primary table.",
    "#' @param x layout",
    "#' @export",
    "#' @keywords internal",
    "dim.gggenomes_layout <- function(x) {",
    "  dim(x)",
    "}",
    sep = "\n",
    file = file.path(path, "R", "strand.R")
  )
  # Provide the dummy class so document() doesn't fail loading.
  cat(
    "structure(list(), class = \"gggenomes_layout\")",
    sep = "\n",
    file = file.path(path, "R", "zzz.R")
  )
  suppressWarnings(attachment::att_amend_desc(path = path))

  res <- suppressMessages(suppressWarnings(.find_missing_tags(package.dir = path)))

  flagged <- res$functions[res$functions$test_has_export_and_return == "not_ok", ]
  expect_true("dim.gggenomes_layout" %in% flagged$topic,
    info = "S3 method with own Rd and no @return must be flagged"
  )
  expect_false("strand_chr" %in% flagged$topic,
    info = "S3 generic with @return must stay clean"
  )
})

test_that("plain function without @return is still flagged (regression guard)", {
  local_tempdir_clean()
  path <- local_s3_pkg()
  cat(
    "#' Plain helper",
    "#' @export",
    "helper <- function() {",
    "  1",
    "}",
    sep = "\n",
    file = file.path(path, "R", "helper.R")
  )
  suppressWarnings(attachment::att_amend_desc(path = path))

  res <- suppressMessages(suppressWarnings(.find_missing_tags(package.dir = path)))

  flagged <- res$functions[res$functions$test_has_export_and_return == "not_ok", ]
  expect_true("helper" %in% flagged$topic)
})

test_that("S3 method documented with @describeIn inherits @return from the generic (#105 Copilot)", {
  local_tempdir_clean()
  path <- local_s3_pkg()
  cat(
    "#' Generic",
    "#' @param x x",
    "#' @return character",
    "#' @export",
    "foo <- function(x) {",
    "  UseMethod(\"foo\")",
    "}",
    "",
    "#' @describeIn foo Method for character",
    "#' @export",
    "foo.character <- function(x) {",
    "  x",
    "}",
    sep = "\n",
    file = file.path(path, "R", "foo.R")
  )
  suppressWarnings(attachment::att_amend_desc(path = path))

  res <- suppressMessages(suppressWarnings(.find_missing_tags(package.dir = path)))

  flagged <- res$functions[res$functions$test_has_export_and_return == "not_ok", ]
  expect_false("foo.character" %in% flagged$topic,
    info = "@describeIn must group the method under the generic so the inherited @return propagates"
  )
  expect_false("foo" %in% flagged$topic)
})
