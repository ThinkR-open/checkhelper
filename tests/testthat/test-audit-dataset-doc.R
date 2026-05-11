test_that("audit_dataset_doc() exists with the expected signature", {
  expect_true(is.function(audit_dataset_doc))
  expect_named(formals(audit_dataset_doc), c("pkg"))
})

test_that("audit_dataset_doc() returns an empty tibble when data/ does not exist", {
  path <- tempfile("pkg-empty-")
  dir.create(path)
  dir.create(file.path(path, "R"))
  writeLines("Package: foo", file.path(path, "DESCRIPTION"))
  on.exit(unlink(path, recursive = TRUE))
  out <- suppressMessages(audit_dataset_doc(path))
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0L)
  expect_true(all(c("name", "has_doc") %in% colnames(out)))
})

test_that("audit_dataset_doc() reports datasets present in data/", {
  path <- tempfile("pkg-data-")
  dir.create(path)
  dir.create(file.path(path, "R"))
  dir.create(file.path(path, "data"))
  writeLines("Package: foo", file.path(path, "DESCRIPTION"))
  iris_path <- file.path(path, "data", "iris.rda")
  save(iris, file = iris_path)
  on.exit(unlink(path, recursive = TRUE))
  out <- suppressMessages(audit_dataset_doc(path))
  expect_equal(nrow(out), 1L)
  expect_equal(out$name, "iris")
  expect_false(out$has_doc)
})

test_that("audit_dataset_doc() emits a cli message", {
  path <- tempfile("pkg-empty-")
  dir.create(path)
  dir.create(file.path(path, "R"))
  writeLines("Package: foo", file.path(path, "DESCRIPTION"))
  on.exit(unlink(path, recursive = TRUE))
  expect_message(audit_dataset_doc(path), regexp = "dataset")
})

# --- Edge / coverage tests --------------------------------------------------

local_pkg_with_data <- function(rda_names = character(), r_files = list(),
                                envir = parent.frame()) {
  path <- tempfile("pkg-ds-")
  dir.create(file.path(path, "data"), recursive = TRUE)
  dir.create(file.path(path, "R"), recursive = TRUE)
  for (nm in rda_names) {
    x <- 1
    save(x, file = file.path(path, "data", paste0(nm, ".rda")))
  }
  for (nm in names(r_files)) {
    writeLines(r_files[[nm]], file.path(path, "R", nm))
  }
  withr::defer(unlink(path, recursive = TRUE), envir = envir)
  path
}

test_that("audit_dataset_doc() returns empty tibble when data/ is missing", {
  pkg <- tempfile("pkg-no-data-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  out <- suppressMessages(audit_dataset_doc(pkg))
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
})

test_that("audit_dataset_doc() returns empty tibble when data/ has no rda files", {
  pkg <- tempfile("pkg-empty-data-")
  dir.create(file.path(pkg, "data"), recursive = TRUE)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  out <- suppressMessages(audit_dataset_doc(pkg))
  expect_equal(nrow(out), 0L)
})

test_that("audit_dataset_doc() handles a package without an R/ directory", {
  pkg <- tempfile("pkg-no-r-")
  dir.create(file.path(pkg, "data"), recursive = TRUE)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  x <- 1
  save(x, file = file.path(pkg, "data", "demo.rda"))

  out <- suppressMessages(audit_dataset_doc(pkg))
  expect_equal(nrow(out), 1L)
  expect_false(out$has_doc)
})

test_that("audit_dataset_doc() detects a documented dataset via @name", {
  pkg <- local_pkg_with_data(
    rda_names = "demo",
    r_files = list("demo-data.R" = c(
      "#' Demo dataset",
      "#'",
      "#' @name demo",
      "#' @format A vector.",
      "NULL"
    ))
  )

  out <- suppressMessages(audit_dataset_doc(pkg))
  expect_true(out$has_doc[out$name == "demo"])
})

test_that("audit_dataset_doc() detects a documented dataset via quoted string reference", {
  pkg <- local_pkg_with_data(
    rda_names = "demo",
    r_files = list("demo-data.R" = c(
      "#' Demo dataset",
      "#' @format A vector.",
      '"demo"'
    ))
  )

  out <- suppressMessages(audit_dataset_doc(pkg))
  expect_true(out$has_doc[out$name == "demo"])
})

test_that(".get_data_info() errors when the dataset name does not exist", {
  pkg <- local_pkg_with_data(rda_names = "demo")
  expect_error(
    withr::with_dir(pkg, checkhelper:::.get_data_info("nope")),
    regexp = "not found"
  )
})

test_that(".get_data_info() errors when multiple rda files share the same stem", {
  # Force two rda files with the same case-insensitive stem on a
  # case-sensitive filesystem (Linux/CI).
  skip_on_os("windows")
  pkg <- tempfile("pkg-dupe-")
  dir.create(file.path(pkg, "data"), recursive = TRUE)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  x <- 1
  save(x, file = file.path(pkg, "data", "demo.rda"))
  save(x, file = file.path(pkg, "data", "demo.RData"))

  expect_error(
    withr::with_dir(pkg, checkhelper:::.get_data_info("demo")),
    regexp = "multiple files"
  )
})
