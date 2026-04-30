test_that("audit_globals() exists with the expected signature", {
  expect_true(is.function(audit_globals))
  expect_named(formals(audit_globals), c("pkg", "checks"))
  expect_null(eval(formals(audit_globals)$checks))
})

test_that("audit_globals() returns either NULL or a 2-element list (globalVariables, functions)", {
  skip_on_cran()
  local_tempdir_clean()
  path <- suppressWarnings(create_example_pkg())
  on.exit(unlink(path, recursive = TRUE), add = TRUE)
  out <- suppressMessages(suppressWarnings(audit_globals(path)))
  if (!is.null(out)) {
    expect_type(out, "list")
    expect_named(out, c("globalVariables", "functions"))
  } else {
    succeed("audit_globals returned NULL — package had no notes")
  }
})

test_that("audit_globals() emits a cli message", {
  skip_on_cran()
  local_tempdir_clean()
  path <- suppressWarnings(create_example_pkg())
  on.exit(unlink(path, recursive = TRUE), add = TRUE)
  expect_message(
    suppressWarnings(audit_globals(path)),
    regexp = "global"
  )
})

test_that("audit_globals(checks = ...) reuses a precomputed rcmdcheck and does not re-run R CMD check", {
  # Faux objet rcmdcheck minimal: une seule note avec deux globals connues.
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

  # Sentinelle: rcmdcheck::rcmdcheck est stubbé pour exploser si appelé.
  # Si la branche `checks =` est correctement câblée, on ne le déclenche jamais.
  testthat::with_mocked_bindings(
    rcmdcheck = function(...) stop("rcmdcheck must NOT be called when checks= is supplied"),
    .package = "checkhelper",
    {
      out <- suppressMessages(audit_globals(pkg = "/path/does/not/exist",
                                            checks = fake_checks))
    }
  )

  expect_type(out, "list")
  expect_named(out, c("globalVariables", "functions"))
  expect_true("foo" %in% out$globalVariables$variable)
  expect_true("bar" %in% out$functions$variable)
})

test_that("audit_globals(checks = ...) returns NULL when checks has no relevant notes", {
  fake_checks <- list(notes = character())
  out <- suppressMessages(audit_globals(pkg = "/path/does/not/exist",
                                        checks = fake_checks))
  expect_null(out)
})
