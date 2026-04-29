test_that("find_missing_tags() does not leak the target package into the session (#77)", {
  pkg_path <- tempfile(pattern = "pkg-")
  dir.create(pkg_path)
  on.exit(unlink(pkg_path, recursive = TRUE), add = TRUE)
  usethis::create_package(file.path(pkg_path, "pkg.leak"), open = FALSE)
  pkg_dir <- file.path(pkg_path, "pkg.leak")

  writeLines(
    c(
      "#' Exported f",
      "#' @return 1",
      "#' @export",
      "f_pub_leak_marker <- function() 1",
      "",
      "#' @noRd",
      "f_priv_leak_marker <- function() 2"
    ),
    file.path(pkg_dir, "R", "fns.R")
  )
  suppressWarnings(attachment::att_amend_desc(path = pkg_dir, must.exist = FALSE))

  # att_amend_desc may have already loaded pkg.leak. Reset to a clean
  # baseline so the test really measures whether find_missing_tags keeps
  # the package around afterwards.
  if ("package:pkg.leak" %in% search()) {
    detach("package:pkg.leak", character.only = TRUE, unload = TRUE)
  }
  if ("pkg.leak" %in% loadedNamespaces()) {
    try(pkgload::unload("pkg.leak"), silent = TRUE)
    if ("pkg.leak" %in% loadedNamespaces()) {
      try(unloadNamespace("pkg.leak"), silent = TRUE)
    }
  }
  on.exit(
    {
      if ("package:pkg.leak" %in% search()) {
        try(detach("package:pkg.leak", character.only = TRUE, unload = TRUE), silent = TRUE)
      }
      if ("pkg.leak" %in% loadedNamespaces()) {
        try(unloadNamespace("pkg.leak"), silent = TRUE)
      }
    },
    add = TRUE
  )

  suppressMessages(suppressWarnings(find_missing_tags(pkg_dir)))

  expect_false("package:pkg.leak" %in% search(),
    info = "target package should not be left on the search path")
  expect_false("pkg.leak" %in% loadedNamespaces(),
    info = "target package's namespace should not stay loaded after the call")
})
