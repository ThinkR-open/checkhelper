test_that("find_missing_tags() accepts @returns as well as @return (#81)", {
  pkg_path <- tempfile(pattern = "pkg-")
  dir.create(pkg_path)
  on.exit(unlink(pkg_path, recursive = TRUE), add = TRUE)

  usethis::create_package(file.path(pkg_path, "pkg.returns"), open = FALSE)
  pkg_dir <- file.path(pkg_path, "pkg.returns")

  writeLines(
    c(
      "#' f",
      "#' @returns the number 1",
      "#' @export",
      "f <- function() 1",
      "",
      "#' g",
      "#' @return the number 2",
      "#' @export",
      "g <- function() 2"
    ),
    file.path(pkg_dir, "R", "fns.R")
  )
  suppressWarnings(attachment::att_amend_desc(path = pkg_dir, must.exist = FALSE))

  out <- suppressMessages(suppressWarnings(find_missing_tags(pkg_dir)))
  fns <- out[["functions"]]

  expect_true(all(c("f", "g") %in% fns$topic))
  for (nm in c("f", "g")) {
    row <- fns[fns$topic == nm, ]
    expect_true(row$has_return,
      info = paste0("`", nm, "` should be considered as having a return tag"))
    expect_true(row$not_empty_return_value,
      info = paste0("`", nm, "` should expose a non-empty return value"))
    expect_equal(as.character(row$test_has_export_and_return), "ok")
  }
})
