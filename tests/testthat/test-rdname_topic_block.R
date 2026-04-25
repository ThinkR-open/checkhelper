test_that("find_missing_tags() doesn't flag aliases pointing to a topic-only block (#82)", {
  pkg_path <- tempfile(pattern = "pkg-")
  dir.create(pkg_path)
  on.exit(unlink(pkg_path, recursive = TRUE), add = TRUE)

  usethis::create_package(file.path(pkg_path, "pkg.rdname"), open = FALSE)
  pkg_dir <- file.path(pkg_path, "pkg.rdname")

  # Topic block (NULL object) holds the @return tag, function uses @rdname.
  writeLines(
    c(
      "#' My topic",
      "#' @return some kind of value",
      "#' @name hello",
      "NULL",
      "",
      "#' @rdname hello",
      "#' @export",
      "my_fun <- function() invisible()"
    ),
    file.path(pkg_dir, "R", "function.R")
  )
  suppressWarnings(attachment::att_amend_desc(path = pkg_dir, must.exist = FALSE))

  out <- suppressMessages(suppressWarnings(find_missing_tags(pkg_dir)))
  fns <- out[["functions"]]

  expect_true("my_fun" %in% fns$topic)
  row <- fns[fns$topic == "my_fun", ]
  expect_equal(as.character(row$test_has_export_and_return), "ok",
    info = "alias inherits @return from the topic block via @rdname")
})
