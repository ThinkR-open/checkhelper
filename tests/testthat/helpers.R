test_that("Package version required", {

  # Check the version of the package roxygen2 to take into account the breaking change.
  expect_true(packageVersion("roxygen2") > "7.1.2")

})

# Silence lifecycle deprecation warnings globally; tests that explicitly
# exercise the deprecation layer override this with `withr::local_options()`.
options(lifecycle_verbosity = "quiet")

# Snapshot tempdir() at test entry and unlink anything new at teardown.
# Use this in tests that call rcmdcheck (audit_globals/fix_globals path)
# so they don't leak artefacts that downstream tests
# (test-check_clean_userspace) detect as pre-existing files.
local_tempdir_clean <- function(envir = parent.frame()) {
  before <- list.files(tempdir(), all.files = TRUE, no.. = TRUE)
  withr::defer(
    {
      after <- list.files(tempdir(), all.files = TRUE, no.. = TRUE)
      added <- setdiff(after, before)
      for (entry in added) {
        unlink(file.path(tempdir(), entry), recursive = TRUE, force = TRUE)
      }
    },
    envir = envir
  )
}
