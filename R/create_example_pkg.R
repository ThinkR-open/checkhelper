
#' Create a package example producing notes and errors
#'
#' @param path Path where to store the example package
#' @param with_functions Logical. Whether there will be functions or not (with notes)
#' @param with_extra_notes Logical. Whether there are extra notes or not
#' @param with_nonascii Logical. If `TRUE`, copy a fixture file containing
#'   non-ASCII characters (French comments, string literals, message text)
#'   so `audit_ascii()` / `fix_ascii()` have something to surface.
#' @param with_undocumented_data Logical. If `TRUE`, save a small
#'   `data.frame` to `data/` *without* writing a roxygen block for it,
#'   so `audit_dataset_doc()` flags it as undocumented.
#' @rdname create_example_pkg
#' @export
#' @return Path where the example package is stored.
#' @examples
#' create_example_pkg()
create_example_pkg <- function(path = tempfile(pattern = "pkg-"),
                               with_functions = TRUE,
                               with_extra_notes = FALSE,
                               with_nonascii = FALSE,
                               with_undocumented_data = FALSE) {
  if (!requireNamespace("usethis", quietly = TRUE) |
    !requireNamespace("attachment", quietly = TRUE)) {
    stop("Packages 'usethis' and 'attachment' are required to use this function in our examples and tests.")
  }

  # Create fake package ----
  if (!dir.exists(path)) {
    dir.create(path)
  } else {
    stop(path, " already exists")
  }

  # Create fake package
  usethis::create_package(file.path(path, "checkpackage"), open = FALSE)
  # on.exit(unlink(file.path(path, "checkpackage"), recursive = TRUE))

  if (isTRUE(with_extra_notes)) {
    extra_dir_path <- file.path(
      path, "checkpackage", "inst", "I build", "a very", "long_name",
      "that should be",
      "not_ok", "for_checks",
      "and hopefully", "lead to", "some", "extra_notes"
    )
    dir.create(extra_dir_path, recursive = TRUE)
    cat("for extra notes",
      file = file.path(extra_dir_path, "super_long_file_name_for_tests_to_extra_notes")
    )
  }

  if (isTRUE(with_functions)) {
    # Create function no visible global variables and missing documented functions
    # And return empty
    file.copy(
      system.file("bad-function-examples.R", package = "checkhelper"),
      file.path(path, "checkpackage", "R", "function.R")
    )
  }

  if (isTRUE(with_nonascii)) {
    file.copy(
      system.file("nonascii-examples.R", package = "checkhelper"),
      file.path(path, "checkpackage", "R", "nonascii.R")
    )
  }

  if (isTRUE(with_undocumented_data)) {
    data_dir <- file.path(path, "checkpackage", "data")
    dir.create(data_dir, showWarnings = FALSE)
    demo_dataset <- data.frame(
      id = seq_len(3),
      value = c(1.1, 2.2, 3.3)
    )
    save(demo_dataset, file = file.path(data_dir, "demo_dataset.rda"))
  }

  path <- file.path(path, "checkpackage")
  # This package will have warnings, but it is intentional
  # so that functions can detect problems
  suppressWarnings(attachment::att_amend_desc(path = path, must.exist = FALSE))

  fixtures <- c(
    if (isTRUE(with_functions)) "bad-function examples (tags, globals)",
    if (isTRUE(with_extra_notes)) "extra-note long-path file",
    if (isTRUE(with_nonascii)) "non-ASCII source file",
    if (isTRUE(with_undocumented_data)) "undocumented dataset under data/"
  )

  cli::cli_inform(c(
    "v" = "Demo package created at {.path {path}}",
    "i" = if (length(fixtures)) {
      "Active fixtures: {fixtures}."
    } else {
      "No fixtures activated (all with_* flags are FALSE)."
    }
  ))

  invisible(path)
}
