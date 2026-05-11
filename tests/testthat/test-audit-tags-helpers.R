# Coverage-targeted tests for the small audit_tags internals.

local_pkg_for_block <- function(envir = parent.frame()) {
  # Build a real roxygen2-parseable mini-package so we can extract blocks
  # without a fragile mock of roxygen2's internal block class.
  path <- tempfile("pkg-tags-")
  dir.create(file.path(path, "R"), recursive = TRUE)
  writeLines(
    c(
      "Package: tagslab",
      "Title: t",
      "Version: 0.0.0.9000",
      "Authors@R: person('A', 'B', email = 'a@b.c', role = c('aut', 'cre'))",
      "Description: tagslab is a fixture.",
      "License: MIT + file LICENSE",
      "Encoding: UTF-8"
    ),
    file.path(path, "DESCRIPTION")
  )
  withr::defer(unlink(path, recursive = TRUE), envir = envir)
  path
}

write_R_file <- function(path, name, lines) {
  writeLines(lines, file.path(path, "R", name))
}

parse_blocks <- function(path) {
  getFromNamespace("parse_package", "roxygen2")(path, env = NULL)
}

test_that("block_has_return_tag() returns TRUE when @return is present", {
  pkg <- local_pkg_for_block()
  write_R_file(pkg, "a.R", c(
    "#' Foo",
    "#' @return an integer",
    "#' @export",
    "foo <- function() 1L"
  ))

  blocks <- parse_blocks(pkg)
  res <- checkhelper:::block_has_return_tag(blocks[[1]])
  expect_true(res)
})

test_that("block_has_return_tag() returns FALSE when there is neither @return nor @inherit", {
  pkg <- local_pkg_for_block()
  write_R_file(pkg, "a.R", c(
    "#' Foo",
    "#' @export",
    "foo <- function() 1L"
  ))

  blocks <- parse_blocks(pkg)
  res <- checkhelper:::block_has_return_tag(blocks[[1]])
  expect_false(res)
})

test_that("block_has_return_tag() returns TRUE on bare @inherit (no fields = inherit all)", {
  pkg <- local_pkg_for_block()
  write_R_file(pkg, "a.R", c(
    "#' Foo bar",
    "#' @return an integer",
    "foo <- function() 1L",
    "",
    "#' @inherit foo",
    "#' @export",
    "bar <- function() foo()"
  ))

  blocks <- parse_blocks(pkg)
  has_inherit <- vapply(blocks, function(b) {
    tags <- vapply(b[["tags"]], function(t) t[["tag"]], character(1))
    "inherit" %in% tags
  }, logical(1))
  bar_block <- blocks[[which(has_inherit)[1L]]]

  res <- checkhelper:::block_has_return_tag(bar_block)
  expect_true(res)
})

test_that("topic_block_returns() skips topic blocks without an rdname / name / topic", {
  # A synthetic topic block with no rdname / name and topic == "" should be
  # silently skipped by topic_block_returns().
  pkg <- local_pkg_for_block()
  write_R_file(pkg, "a.R", c(
    "#' Foo",
    "#' @return an integer",
    "foo <- function() 1L"
  ))

  blocks <- parse_blocks(pkg)
  res <- checkhelper:::topic_block_returns(blocks)
  expect_true(is.character(res))
})

test_that("unload_target_pkg() is a no-op on an empty / missing pkg_name", {
  expect_silent(checkhelper:::unload_target_pkg(NULL, ns_before = character(0), search_before = character(0)))
  expect_silent(checkhelper:::unload_target_pkg("", ns_before = character(0), search_before = character(0)))
})

test_that("unload_target_pkg() is a no-op when the package was already loaded before", {
  # `tools` is in loadedNamespaces() by default in any R session. Passing
  # it in ns_before means the function must not attempt to unload it.
  ns_before <- loadedNamespaces()
  search_before <- search()
  expect_silent(checkhelper:::unload_target_pkg(
    "tools",
    ns_before = ns_before,
    search_before = search_before
  ))
  expect_true("tools" %in% loadedNamespaces())
})
