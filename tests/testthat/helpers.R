# Silence expected lifecycle deprecations for the current test.
local_quiet_deprecation <- function(envir = parent.frame()) {
  withr::local_options(lifecycle_verbosity = "quiet", .local_envir = envir)
}

# Discard output and messages for the current test.
# For file-scope fixtures, use `quiet_create_example_pkg()` instead.
local_quiet <- function(envir = parent.frame()) {
  if (sink.number(type = "message") == 2L) {
    withr::local_message_sink(nullfile(), .local_envir = envir)
  }
  withr::local_output_sink(nullfile(), .local_envir = envir)
  invisible()
}

# Create the example package without toolchain output or expected warnings.
quiet_create_example_pkg <- function(...) {
  local_quiet(environment())
  suppressWarnings(create_example_pkg(...))
}

# Remove files added to `tempdir()` when the test or file completes.
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
