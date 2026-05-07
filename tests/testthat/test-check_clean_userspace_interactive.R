# Regression test for #87: examples wrapped in `if (interactive())`
# were being executed by .check_clean_userspace() because
# devtools::run_examples() ran in the *current* R session (which is
# interactive when launched from RStudio's Cmd+Shift+E shortcut), so
# `interactive()` returned TRUE inside the example body.
#
# The fix is to delegate to a fresh non-interactive subprocess by
# passing `fresh = TRUE` to devtools::run_examples(). This test
# captures that contract: it intercepts the call and asserts the flag.

test_that(".check_clean_userspace() runs examples in a fresh non-interactive R", {
  local_tempdir_clean()
  path <- suppressWarnings(create_example_pkg())
  suppressWarnings(attachment::att_amend_desc(path = path))

  captured <- new.env(parent = emptyenv())
  fake_run_examples <- function(...) {
    captured$args <- list(...)
    invisible(NULL)
  }

  suppressWarnings(suppressMessages(try(
    testthat::with_mocked_bindings(
      .check_clean_userspace(pkg = path, check_output = tempfile("check_output")),
      run_examples = fake_run_examples,
      .package = "devtools"
    ),
    silent = TRUE
  )))

  expect_true(isTRUE(captured$args$fresh),
    info = paste(
      "devtools::run_examples() must be called with fresh = TRUE so",
      "examples run in a non-interactive subprocess (#87). Got:",
      paste(deparse(captured$args$fresh), collapse = " ")
    )
  )

  unlink(path, recursive = TRUE)
})
