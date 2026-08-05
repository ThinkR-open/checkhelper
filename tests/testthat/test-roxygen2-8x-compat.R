# Regression guards for roxygen2 8.x: the DESCRIPTION field migration
# (RoxygenNote -> Config/roxygen2/version) must not break usethis-based
# scaffolding, and the getFromNamespace-based audit pipeline must keep
# working end-to-end on a package documented by the installed roxygen2.

test_that("create_example_pkg produces a roxygen2-managed package regardless of field migration", {
  skip_if_not_installed("usethis")
  skip_if_not_installed("attachment")

  path <- quiet_create_example_pkg()
  on.exit(unlink(dirname(path), recursive = TRUE), add = TRUE)

  d <- desc::desc(file.path(path, "DESCRIPTION"))

  # Which of the two version fields ends up in the scaffolded DESCRIPTION
  # depends on the whole roxygen2/usethis/attachment combination on the
  # machine, not on the roxygen2 version alone. The invariant checkhelper
  # relies on is the same one usethis uses: the package counts as
  # roxygen-managed when EITHER field is present.
  expect_true(
    any(d$has_fields(c("RoxygenNote", "Config/roxygen2/version")))
  )
})

test_that("find_missing_tags audits an 8.x-documented example package without error", {
  skip_if_not_installed("usethis")
  skip_if_not_installed("attachment")

  path <- quiet_create_example_pkg()
  on.exit(unlink(dirname(path), recursive = TRUE), add = TRUE)

  # The audit pipeline reimplements roxygenise() through roxygen2 internals
  # (getFromNamespace). It must run end-to-end on a package documented by the
  # installed roxygen2, whatever the DESCRIPTION field layout.
  out <- suppressWarnings(suppressMessages(find_missing_tags(path)))

  expect_type(out, "list")
  expect_length(out, 3)
  expect_equal(names(out), c("package_doc", "data", "functions"))
  # The exported-without-@return fixture must still be flagged: this is the
  # core contract, and it is what proves the block classification survived the
  # roxygen2 8.x changes to block/roclet handling.
  expect_true(
    "my_long_fun_name_for_multiple_lines_globals" %in% out[["functions"]][["topic"]]
  )
  expect_true(
    any(out[["functions"]][["test_has_export_and_return"]] == "not_ok")
  )
})
