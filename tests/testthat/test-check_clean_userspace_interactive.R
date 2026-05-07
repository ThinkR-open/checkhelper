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
  # Stub the rest of the heavy pipeline so this contract test stays
  # cheap and deterministic. Without this, the test was running the
  # full devtools::test + rcmdcheck::rcmdcheck + devtools::build_vignettes
  # pipeline against a freshly created example package — tens of seconds
  # plus CRAN-mirror dependence — only to check one mocked argument
  # (Copilot review on PR #106). Internal namespace access goes through
  # checkhelper::: so the mock survives `R CMD check` against the
  # installed package (Copilot review on PR #107).
  fake_test <- function(...) invisible(NULL)
  fake_rcmdcheck <- function(...) {
    list(notes = character(0), warnings = character(0), errors = character(0))
  }
  fake_build_vignettes <- function(...) NULL

  # No `try(silent = TRUE)`: a real failure inside .check_clean_userspace()
  # (e.g. attachment::att_amend_desc() blowing up, a mock-binding miss)
  # must surface as a real error rather than being silently dropped and
  # then misreported as "fresh != TRUE" (Copilot review of #106).
  suppressWarnings(suppressMessages(
    testthat::with_mocked_bindings(
      testthat::with_mocked_bindings(
        checkhelper:::.check_clean_userspace(pkg = path, check_output = tempfile("check_output")),
        rcmdcheck = fake_rcmdcheck,
        .package = "rcmdcheck"
      ),
      test = fake_test,
      run_examples = fake_run_examples,
      build_vignettes = fake_build_vignettes,
      .package = "devtools"
    )
  ))

  expect_true(isTRUE(captured$args$fresh),
    info = paste(
      "devtools::run_examples() must be called with fresh = TRUE so",
      "examples run in a non-interactive subprocess (#87). Got:",
      paste(deparse(captured$args$fresh), collapse = " ")
    )
  )

  unlink(path, recursive = TRUE)
})
