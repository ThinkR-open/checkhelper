test_that("my_function works properly", {
  data <- list(
    name = "unit-test",
    description = "Testing this fct",
    rows = 12,
    cols = 3,
    items = list(
      list(name = "first", class = "character"),
      list(name = "second", class = "numeric")
    ),
    source = "ThinkR"
  )
  dir_temp <- tempdir()
  path_to_save <- file.path(dir_temp, "test_data_doc.R")
  template <- system.file("template", "data-doc.R", package = "checkhelper")
  render_template(template, path_to_save, data)

  expect_true(file.exists(path_to_save))
  text <- readLines(path_to_save)
  lapply(data, function(x) {
    if (is.list(x)) {
      lapply(x, function(x) {
        expect_true(any(grepl(x[[1]], x = text)))
      })
    } else {
      expect_true(any(grepl(x, x = text)))
    }
  })
})
