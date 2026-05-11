# Coverage-targeted tests for branches of audit_globals.R that aren't
# exercised by the existing suite. Each block targets a specific set
# of zero-coverage lines reported by covr::zero_coverage().

# audit_globals(): NULL path when the checker returns nothing -----------------

test_that("audit_globals() returns NULL with a verbose message when no globals", {
  expect_message(
    out <- testthat::with_mocked_bindings(
      audit_globals("/tmp/anywhere"),
      .get_no_visible = function(...) NULL,
      .package = "checkhelper"
    ),
    regexp = "no global notes"
  )
  expect_null(out)
})

# fix_globals(write = FALSE): print path -------------------------------------

test_that("fix_globals(write = FALSE) prints both blocks and operators block", {
  globals <- list(
    globalVariables = tibble::tibble(fun = "f", variable = "var_a"),
    functions = tibble::tibble(fun = "f", variable = "extern_fn", proposed = "ns::extern_fn"),
    operators = tibble::tibble(fun = "f", variable = ":=", source_pkg = "data.table;rlang")
  )

  res <- testthat::with_mocked_bindings(
    suppressMessages(fix_globals("/tmp/anywhere", write = FALSE)),
    .get_no_visible = function(...) globals,
    .package = "checkhelper"
  )

  expect_null(res)
})

# fix_globals(write = TRUE) without an R/ directory --------------------------

test_that("fix_globals(write = TRUE) creates R/ when it does not exist", {
  pkg <- tempfile("pkg-no-r-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  expect_false(dir.exists(file.path(pkg, "R")))

  globals <- list(
    globalVariables = tibble::tibble(fun = "f", variable = "first_var"),
    functions = tibble::tibble(
      fun = character(0), variable = character(0), proposed = character(0)
    )
  )

  res <- testthat::with_mocked_bindings(
    suppressMessages(fix_globals(pkg, write = TRUE)),
    .get_no_visible = function(...) globals,
    .package = "checkhelper"
  )

  expect_true(dir.exists(file.path(pkg, "R")))
  expect_true(file.exists(file.path(pkg, "R", "globals.R")))
  expect_equal(normalizePath(res), normalizePath(file.path(pkg, "R", "globals.R")))
})

# fix_globals(write = TRUE) with operators -----------------------------------

test_that("fix_globals(write = TRUE) prints the operators block and informs", {
  pkg <- tempfile("pkg-ops-")
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  globals <- list(
    globalVariables = tibble::tibble(fun = "f", variable = "var_a"),
    functions = tibble::tibble(
      fun = character(0), variable = character(0), proposed = character(0)
    ),
    operators = tibble::tibble(fun = "f", variable = ":=", source_pkg = "data.table;rlang")
  )

  expect_message(
    testthat::with_mocked_bindings(
      fix_globals(pkg, write = TRUE),
      .get_no_visible = function(...) globals,
      .package = "checkhelper"
    ),
    regexp = "operators / pronouns above"
  )
})

# fix_globals(): NULL globals path -------------------------------------------

test_that("fix_globals() returns invisibly with no-op message when no globals", {
  expect_message(
    res <- testthat::with_mocked_bindings(
      fix_globals("/tmp/anywhere"),
      .get_no_visible = function(...) NULL,
      .package = "checkhelper"
    ),
    regexp = "no globals to declare"
  )
  expect_null(res)
})

# extract_existing_globals(): parse-error path -------------------------------

test_that("extract_existing_globals() returns character(0) when globals.R does not parse", {
  globals_path <- tempfile(fileext = ".R")
  writeLines("this is ( not valid R", globals_path)
  on.exit(unlink(globals_path), add = TRUE)

  res <- checkhelper:::extract_existing_globals(globals_path)
  expect_equal(res, character(0))
})

# extract_existing_globals(): skips non-globalVariables calls ----------------

test_that("extract_existing_globals() skips calls that are not globalVariables()", {
  globals_path <- tempfile(fileext = ".R")
  writeLines(
    c(
      'message("hello")',
      'x <- 1 + 1',
      'utils::globalVariables(c("real_var"))'
    ),
    globals_path
  )
  on.exit(unlink(globals_path), add = TRUE)

  res <- checkhelper:::extract_existing_globals(globals_path)
  expect_equal(res, "real_var")
})

# is_globalVariables_call(): every branch ------------------------------------

test_that("is_globalVariables_call() returns FALSE on non-call inputs", {
  expect_false(checkhelper:::is_globalVariables_call(quote(x)))
  expect_false(checkhelper:::is_globalVariables_call(42))
  expect_false(checkhelper:::is_globalVariables_call("string"))
})

test_that("is_globalVariables_call() recognises both bare and utils:: forms", {
  expect_true(checkhelper:::is_globalVariables_call(quote(globalVariables(c("x")))))
  expect_true(checkhelper:::is_globalVariables_call(quote(utils::globalVariables(c("x")))))
})

test_that("is_globalVariables_call() returns FALSE for other namespaced calls", {
  expect_false(checkhelper:::is_globalVariables_call(quote(other::fn(x))))
  expect_false(checkhelper:::is_globalVariables_call(quote(utils::other_fn(x))))
  expect_false(checkhelper:::is_globalVariables_call(quote(some_fn(x))))
})

# .print_globals(): malformed input ------------------------------------------

test_that(".print_globals() errors on a malformed globals list", {
  expect_error(
    checkhelper:::.print_globals(globals = list()),
    regexp = "globals should be a list"
  )
})

test_that(".print_globals() fetches globals when called without the globals arg", {
  res <- testthat::with_mocked_bindings(
    checkhelper:::.print_globals(path = "/tmp/anywhere", message = FALSE),
    .get_no_visible = function(path, ...) NULL,
    .package = "checkhelper"
  )
  expect_null(res)
})

test_that(".print_globals() emits 'no globalVariable detected' when message = TRUE", {
  expect_message(
    res <- testthat::with_mocked_bindings(
      checkhelper:::.print_globals(path = "/tmp/anywhere"),
      .get_no_visible = function(path, ...) NULL,
      .package = "checkhelper"
    ),
    regexp = "no globalVariable"
  )
  expect_null(res)
})

# .get_notes(): importfrom branch (line 372) ---------------------------------

test_that(".get_notes() extracts importfrom_function names from quoted suggestions", {
  fake_check <- list(
    notes = c(paste(
      "* checking R code for possible problems ... NOTE",
      "myfun: no visible global function definition for 'helper'",
      "Consider adding",
      "  importFrom(\"somepkg\", \"helper\")",
      "to your NAMESPACE file.",
      sep = "\n"
    ))
  )

  res <- checkhelper:::.get_notes(path = "/tmp/anywhere", checks = fake_check)
  expect_true(any(res$importfrom_function == "helper"))
})

# deprecated::print_globals(): bare call path (line 119) ---------------------

test_that("deprecated print_globals() forwards to .print_globals when no globals arg", {
  withr::local_options(lifecycle_verbosity = "quiet")
  res <- testthat::with_mocked_bindings(
    suppressMessages(suppressWarnings(print_globals(path = "/tmp/anywhere"))),
    .get_no_visible = function(path, ...) NULL,
    .package = "checkhelper"
  )
  expect_null(res)
})
