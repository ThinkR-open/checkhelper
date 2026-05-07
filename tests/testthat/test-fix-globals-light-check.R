# Regression test: fix_globals() / audit_globals() / .get_notes() must
# call rcmdcheck::rcmdcheck() with the *minimum* args needed to surface
# the "no visible binding for global variable" / "no visible global
# function definition" notes.
#
# Those notes are emitted by R CMD check's static code analysis pass
# (`* checking R code for possible problems`). They do NOT depend on
# building vignettes, running tests, running examples, or rendering
# the manual. The historical default (`rcmdcheck(path)` with no args)
# triggered all four heavy phases for nothing — on a package with
# vignettes, that's minutes of wasted time per call.
#
# The contract this test pins down:
#   - build_args must include "--no-build-vignettes"
#   - args must include all of "--no-manual", "--no-tests",
#     "--no-examples", "--no-vignettes"

test_that(".get_notes() runs rcmdcheck with the light flags", {
  captured <- new.env(parent = emptyenv())
  fake_rcmdcheck <- function(path, ...) {
    captured$args <- list(...)
    list(notes = character(0))
  }

  testthat::with_mocked_bindings(
    checkhelper:::.get_notes(path = "."),
    rcmdcheck = fake_rcmdcheck,
    .package = "checkhelper"
  )

  expect_true("--no-build-vignettes" %in% captured$args$build_args,
    info = "build_args must skip vignette building"
  )
  for (flag in c("--no-manual", "--no-tests", "--no-examples", "--no-vignettes")) {
    expect_true(flag %in% captured$args$args,
      info = sprintf("args must include %s", flag)
    )
  }
})

test_that("user-supplied `checks =` bypasses rcmdcheck entirely", {
  called <- FALSE
  fake_rcmdcheck <- function(...) {
    called <<- TRUE
    list(notes = character(0))
  }

  precomputed <- list(notes = character(0))

  testthat::with_mocked_bindings(
    checkhelper:::.get_notes(path = ".", checks = precomputed),
    rcmdcheck = fake_rcmdcheck,
    .package = "checkhelper"
  )

  expect_false(called,
    info = "supplying `checks` must skip the internal rcmdcheck call"
  )
})
