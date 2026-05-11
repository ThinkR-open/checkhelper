
test_that("create_example_pkg works", {
  expect_error(pkgdir <- create_example_pkg(), regexp = NA)

  if (requireNamespace("usethis", quietly = TRUE) &
    requireNamespace("attachment", quietly = TRUE)) {
    expect_true(all(c("DESCRIPTION", "man", "NAMESPACE", "R") %in% list.files(pkgdir)))
    expect_true(file.exists(file.path(pkgdir, "R", "function.R")))
    # clean state
    unlink(pkgdir, recursive = TRUE)
  }
})

# --- Coverage tests for the with_* flags ------------------------------------

test_that("create_example_pkg(with_nonascii = TRUE) copies the non-ASCII fixture", {
  skip_if_not_installed("usethis")
  skip_if_not_installed("attachment")

  pkgdir <- suppressMessages(create_example_pkg(with_nonascii = TRUE))
  on.exit(unlink(dirname(pkgdir), recursive = TRUE), add = TRUE)

  expect_true(file.exists(file.path(pkgdir, "R", "nonascii.R")))
})

test_that("create_example_pkg(with_undocumented_data = TRUE) writes a data/*.rda", {
  skip_if_not_installed("usethis")
  skip_if_not_installed("attachment")

  pkgdir <- suppressMessages(create_example_pkg(with_undocumented_data = TRUE))
  on.exit(unlink(dirname(pkgdir), recursive = TRUE), add = TRUE)

  expect_true(file.exists(file.path(pkgdir, "data", "demo_dataset.rda")))
})

test_that("create_example_pkg() errors when the path already exists", {
  existing <- tempfile("pre-existing-")
  dir.create(existing)
  on.exit(unlink(existing, recursive = TRUE), add = TRUE)

  expect_error(
    create_example_pkg(path = existing),
    regexp = "already exists"
  )
})
