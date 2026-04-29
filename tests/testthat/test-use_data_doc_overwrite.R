test_that("use_data_doc() refuses to overwrite by default and respects overwrite = TRUE (#19)", {
  pkg_path <- tempfile(pattern = "pkg-")
  dir.create(pkg_path)
  on.exit(unlink(pkg_path, recursive = TRUE), add = TRUE)
  usethis::create_package(file.path(pkg_path, "pkg.docover"), open = FALSE)
  pkg_dir <- file.path(pkg_path, "pkg.docover")

  # Create a fake "my_data.rda" so get_data_info() can read its dimensions.
  # We don't need realistic data — use_data_doc() only needs the file to exist.
  data_dir <- file.path(pkg_dir, "data")
  dir.create(data_dir, showWarnings = FALSE)
  my_data <- data.frame(a = 1:3, b = letters[1:3])
  save(my_data, file = file.path(data_dir, "my_data.rda"))

  withr::with_dir(pkg_dir, {
    path <- suppressMessages(use_data_doc("my_data", description = "first version"))
    expect_true(file.exists(path))
    first_content <- readLines(path)

    # Default behaviour: error rather than silently clobber the previous file.
    expect_error(
      suppressMessages(use_data_doc("my_data", description = "second version")),
      regexp = "exists"
    )
    # File untouched.
    expect_identical(readLines(path), first_content)

    # overwrite = TRUE: rewrites and returns the path.
    path2 <- suppressMessages(
      use_data_doc("my_data", description = "second version", overwrite = TRUE)
    )
    expect_identical(path2, path)
    expect_false(identical(readLines(path2), first_content))
  })
})
