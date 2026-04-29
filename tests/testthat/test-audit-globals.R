test_that("audit_globals() exists with the expected signature", {
  expect_true(is.function(audit_globals))
  expect_named(formals(audit_globals), c("pkg"))
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
