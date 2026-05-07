# Regression test: fix_globals(write = TRUE) must merge new globals
# with what's already declared in R/globals.R, not overwrite.
#
# Why: R CMD check filters out names already covered by an existing
# globalVariables() call. So the second time fix_globals() runs on a
# package that already has a curated globals.R, the notes only list
# the *new* uncovered names — overwriting the file would erase the
# previously-declared names and re-flag them on the next check.
# That's a circular game the user can't win.

local_pkg_with_globals <- function(envir = parent.frame()) {
  path <- tempfile("pkg-globals-")
  dir.create(file.path(path, "R"), recursive = TRUE)
  withr::defer(unlink(path, recursive = TRUE), envir = envir)
  path
}

fake_globals <- function(vars) {
  list(
    globalVariables = tibble::tibble(
      fun = rep("my_fun", length(vars)),
      variable = vars
    ),
    functions = tibble::tibble(
      fun = character(0),
      variable = character(0),
      proposed = character(0)
    )
  )
}

test_that("fix_globals(write = TRUE) preserves previously declared globals", {
  path <- local_pkg_with_globals()
  globals_path <- file.path(path, "R", "globals.R")
  writeLines(
    'utils::globalVariables(c("preserved_old_var", "another_old_var"))',
    globals_path
  )

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) fake_globals(c("brand_new_var")),
    .package = "checkhelper"
  )

  written <- paste(readLines(globals_path), collapse = "\n")

  expect_match(written, "brand_new_var", info = "new global must be present")
  expect_match(written, "preserved_old_var",
    info = "previously declared global must survive the rewrite"
  )
  expect_match(written, "another_old_var",
    info = "every previously declared global must survive"
  )
})

test_that("fix_globals(write = TRUE) deduplicates across old / new", {
  path <- local_pkg_with_globals()
  globals_path <- file.path(path, "R", "globals.R")
  writeLines(
    'utils::globalVariables(c("shared", "old_only"))',
    globals_path
  )

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) fake_globals(c("shared", "new_only")),
    .package = "checkhelper"
  )

  # Parse what we wrote and compare to the expected union.
  exprs <- parse(file = globals_path)
  collected <- character(0)
  for (i in seq_along(exprs)) {
    if (is.call(exprs[[i]])) {
      collected <- c(collected, eval(exprs[[i]][[2]]))
    }
  }

  expect_setequal(collected, c("shared", "old_only", "new_only"))
})

test_that("fix_globals(write = TRUE) handles empty fresh + non-empty preserved", {
  # Regression for the bug Copilot flagged on PR #108: when R CMD check
  # surfaces only function notes (no `is_global_variable` rows), the
  # freshly built `globalVariables(unique(c(\n\n)))` body is empty.
  # The previous merge injected a leading `,` before the preserved
  # chunk, producing `c(, \n# ...\n"a")` which parses but errors at
  # eval time with "argument 1 is empty". The output must always be
  # both parseable AND evaluable (sourcing the file must not throw).
  path <- local_pkg_with_globals()
  globals_path <- file.path(path, "R", "globals.R")
  writeLines(
    'utils::globalVariables(c("preserved_only_var"))',
    globals_path
  )

  empty_globals <- list(
    globalVariables = tibble::tibble(
      fun = character(0), variable = character(0)
    ),
    functions = tibble::tibble(
      fun = "fn", variable = "some_fn", proposed = NA_character_
    )
  )

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) empty_globals,
    .package = "checkhelper"
  )

  # The file must parse, and the c(...) argument inside the
  # globalVariables() call must evaluate to a character vector
  # containing the preserved name. The previous bug produced
  # `c(, "preserved_only_var")` which parses but fails at eval
  # with "argument 1 is empty".
  expect_silent(parse(file = globals_path))
  exprs <- parse(file = globals_path)
  found <- character(0)
  for (i in seq_along(exprs)) {
    e <- exprs[[i]]
    if (is.call(e) && length(e) >= 2L) {
      vals <- eval(e[[2]], envir = baseenv())
      expect_true(is.character(vals),
        info = "the c(...) argument must evaluate to a character vector"
      )
      found <- c(found, vals)
    }
  }
  expect_true("preserved_only_var" %in% found,
    info = "the preserved name must round-trip through write+parse"
  )
})

test_that("fix_globals(write = TRUE) handles the no-existing-file case", {
  path <- local_pkg_with_globals()
  globals_path <- file.path(path, "R", "globals.R")
  expect_false(file.exists(globals_path))

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) fake_globals(c("first_var")),
    .package = "checkhelper"
  )

  expect_true(file.exists(globals_path))
  expect_match(paste(readLines(globals_path), collapse = "\n"), "first_var")
})
