test_that("fix_dataset_doc() exists with the expected signature", {
  expect_true(is.function(fix_dataset_doc))
  expect_named(
    formals(fix_dataset_doc),
    c("name", "pkg", "prefix", "description", "source", "overwrite")
  )
})

test_that("fix_dataset_doc() generates a roxygen file under R/", {
  path <- tempfile("pkg-data-")
  dir.create(path)
  dir.create(file.path(path, "R"))
  dir.create(file.path(path, "data"))
  writeLines("Package: foo", file.path(path, "DESCRIPTION"))
  save(iris, file = file.path(path, "data", "iris.rda"))
  on.exit(unlink(path, recursive = TRUE))
  doc_path <- suppressMessages(fix_dataset_doc("iris", pkg = path))
  expect_true(file.exists(doc_path))
  expect_match(doc_path, "doc_iris\\.R$")
})

test_that("fix_dataset_doc() refuses to overwrite by default", {
  path <- tempfile("pkg-data-")
  dir.create(path)
  dir.create(file.path(path, "R"))
  dir.create(file.path(path, "data"))
  writeLines("Package: foo", file.path(path, "DESCRIPTION"))
  save(iris, file = file.path(path, "data", "iris.rda"))
  on.exit(unlink(path, recursive = TRUE))
  suppressMessages(fix_dataset_doc("iris", pkg = path))
  expect_error(
    suppressMessages(fix_dataset_doc("iris", pkg = path)),
    regexp = "already exists|overwrite"
  )
})
