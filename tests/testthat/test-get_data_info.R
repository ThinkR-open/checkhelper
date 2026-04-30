test_that("my_function works properly", {
  temp_dir <- tempdir()
  path_data <- file.path(temp_dir, "data")
  suppressWarnings(dir.create(path_data))
  path_rda <- file.path(path_data, "iris.rda")
  save(iris, file = path_rda)
  withr::with_dir(
    temp_dir,
    {
      result <- get_data_info("iris", "Iris data frame", source = "Thinkr")
    }
  )
  expect_is(result, "list")
  expect_equal(length(result), 6)
  expect_true(all(c("name", "description", "rows", "cols", "items", "source") %in% names(result)), 6)
})

test_that(".get_data_info() errors when the loaded object is not a data.frame", {
  # Pre-fix: the non-data.frame guard was a bare string literal that did
  # nothing. Non-data-frame objects fell through and the whisker template
  # rendered NULL rows / NULL cols silently. Now it must raise.
  withr::with_tempdir({
    dir.create("data")
    not_a_df <- list(a = 1, b = 2)
    save(not_a_df, file = file.path("data", "not_a_df.rda"))

    expect_error(
      checkhelper:::.get_data_info("not_a_df", "desc", "src"),
      regexp = "data\\.frame",
      class = "error"
    )
  })
})
