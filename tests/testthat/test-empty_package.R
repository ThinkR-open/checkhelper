test_that("find_missing_tags() handles a package with no R/ functions (#18)", {
  pkg_path <- tempfile(pattern = "pkg-")
  dir.create(pkg_path)
  on.exit(unlink(pkg_path, recursive = TRUE), add = TRUE)

  usethis::create_package(file.path(pkg_path, "pkg.empty"), open = FALSE)
  pkg_dir <- file.path(pkg_path, "pkg.empty")
  # Empty R/ - no functions to document.
  unlink(list.files(file.path(pkg_dir, "R"), full.names = TRUE))

  # Should not raise.
  out <- suppressMessages(suppressWarnings(find_missing_tags(pkg_dir)))
  expect_type(out, "list")
  expect_named(out, c("package_doc", "data", "functions"))
  expect_equal(nrow(out$functions), 0L)
})
