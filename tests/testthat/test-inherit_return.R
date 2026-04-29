test_that("find_missing_tags() does not flag @inherit X return (#84)", {
  pkg_path <- tempfile(pattern = "pkg-")
  dir.create(pkg_path)
  on.exit(unlink(pkg_path, recursive = TRUE), add = TRUE)
  usethis::create_package(file.path(pkg_path, "pkg.inherit"), open = FALSE)
  pkg_dir <- file.path(pkg_path, "pkg.inherit")

  writeLines(
    c(
      "#' Function Y",
      "#' @return a value",
      "#' @export",
      "y <- function() 1",
      "",
      "#' Function X",
      "#' @inherit y return",
      "#' @export",
      "x <- function() 1"
    ),
    file.path(pkg_dir, "R", "fns.R")
  )
  suppressWarnings(attachment::att_amend_desc(path = pkg_dir, must.exist = FALSE))

  out <- suppressMessages(suppressWarnings(find_missing_tags(pkg_dir)))
  fns <- out[["functions"]]

  expect_true(all(c("x", "y") %in% fns$topic))
  for (nm in c("x", "y")) {
    row <- fns[fns$topic == nm, ]
    expect_equal(as.character(row$test_has_export_and_return), "ok",
      info = paste0("`", nm, "` should be considered as having a return"))
  }
})
