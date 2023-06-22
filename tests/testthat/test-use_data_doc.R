path <- suppressWarnings(create_example_pkg())

test_that("use_doc_data", {
  path_data <- file.path(path, "data")
  suppressWarnings(dir.create(path_data))
  path_rda <- file.path(path_data, "iris.rda")
  save(iris, file = path_rda)
  withr::with_dir(path, {
    test <- use_data_doc("iris")
  })

  expect_true(
    file.exists(file.path(path, test))
  )
})
