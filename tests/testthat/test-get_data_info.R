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
