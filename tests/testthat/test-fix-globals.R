test_that("fix_globals() exists with the expected signature", {
  expect_true(is.function(fix_globals))
  expect_named(formals(fix_globals), c("pkg", "write", "checks"))
  expect_false(eval(formals(fix_globals)$write))
  expect_null(eval(formals(fix_globals)$checks))
})

test_that("fix_globals(write = FALSE) emits a message and does not modify R/globals.R", {
  skip_on_cran()
  local_tempdir_clean()
  local_quiet()
  path <- quiet_create_example_pkg()
  on.exit(unlink(path, recursive = TRUE), add = TRUE)
  globals_file <- file.path(path, "R", "globals.R")
  before_exists <- file.exists(globals_file)
  expect_message(suppressWarnings(fix_globals(path, write = FALSE)))
  after_exists <- file.exists(globals_file)
  expect_equal(before_exists, after_exists)
})

test_that("fix_globals(write = TRUE) writes a parseable R/globals.R", {
  # Pre-fix: the function wrote `printed[["liste_globals"]]` which starts
  # with a banner header `--- Potential GlobalVariables ---`, breaking
  # the resulting file. Pin the contract: the file must parse as R, and
  # it must contain the expected globalVariables(...) call.
  skip_on_cran()
  local_tempdir_clean()
  local_quiet()
  path <- quiet_create_example_pkg()
  on.exit(unlink(path, recursive = TRUE), add = TRUE)

  out <- suppressWarnings(suppressMessages(fix_globals(path, write = TRUE)))

  expect_identical(out, file.path(path, "R", "globals.R"))
  expect_true(file.exists(out))
  expect_silent(parse(file = out))

  written <- readLines(out)
  expect_true(any(grepl("globalVariables\\s*\\(", written)))
  expect_false(any(grepl("^---", written)),
               info = "no banner header should land in the source file")
})

test_that("fix_globals(write = TRUE) still surfaces the functions-to-import list", {
  # Why: in `write = FALSE` mode, `fix_globals()` prints three
  # sections: the functions to import (`liste_funs`), the
  # `globalVariables()` block (`liste_globals`), and the operators /
  # pronouns block (`liste_operators` if any). In `write = TRUE` mode
  # the functions-to-import section was silently dropped, leaving the
  # user blind to the bare-function notes (`where`, `summarise`,
  # `first`, ...) they still had to wire up via `@importFrom`. Pin
  # the contract: in write mode the captured messages must include
  # every detected function name AND a hint pointing at `@importFrom`
  # / NAMESPACE so the user knows where to put them.
  fake_checks <- list(
    notes = c(
      paste(
        "checking R code for possible problems ... NOTE",
        "my_fun: no visible binding for global variable ‘foo’",
        "my_fun: no visible global function definition for ‘where’",
        sep = "\n"
      )
    )
  )

  pkg <- tempfile("fixg-funs-")
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  msgs <- testthat::with_mocked_bindings(
    rcmdcheck = function(...) {
      stop("rcmdcheck must NOT be called when checks= is supplied")
    },
    .package = "checkhelper",
    {
      testthat::capture_messages(
        fix_globals(pkg = pkg, write = TRUE, checks = fake_checks)
      )
    }
  )

  expect_true(
    any(grepl("where", msgs, fixed = TRUE)),
    info = "the function name `where` must surface in fix_globals(write = TRUE) output"
  )
  expect_true(
    any(grepl("@importFrom|NAMESPACE", msgs)),
    info = "the surfaced section must mention NAMESPACE / @importFrom"
  )
})

test_that("fix_globals(checks = ...) reuses a precomputed rcmdcheck and writes a parseable globals.R", {
  fake_checks <- list(
    notes = c(
      paste(
        "checking R code for possible problems ... NOTE",
        "my_fun: no visible binding for global variable ‘foo’",
        "my_fun: no visible global function definition for ‘bar’",
        sep = "\n"
      )
    )
  )

  pkg <- tempfile("fixg-")
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  testthat::with_mocked_bindings(
    rcmdcheck = function(...) stop("rcmdcheck must NOT be called when checks= is supplied"),
    .package = "checkhelper",
    {
      out <- suppressMessages(fix_globals(pkg = pkg, write = TRUE,
                                          checks = fake_checks))
    }
  )

  expect_identical(out, file.path(pkg, "R", "globals.R"))
  expect_true(file.exists(out))
  expect_silent(parse(file = out))
  written <- readLines(out)
  expect_true(any(grepl("\"foo\"", written)))
})
