test_that("Package version required", {

  # Check the version of the package roxygen2 to take into account the breaking change.
  expect_true(packageVersion("roxygen2") > "7.1.2")

})

# Silence lifecycle deprecation warnings globally; tests that explicitly
# exercise the deprecation layer override this with `withr::local_options()`.
options(lifecycle_verbosity = "quiet")
