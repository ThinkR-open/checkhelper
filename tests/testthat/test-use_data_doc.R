path <- quiet_create_example_pkg()
withr::defer(unlink(dirname(path), recursive = TRUE), teardown_env())

test_that("use_doc_data", {
  local_quiet_deprecation()
  local_quiet()
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
