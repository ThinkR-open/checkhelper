# Regression guard for the roxygen2 8.x archival-triggering failure (CRAN
# 2026-08). roxygen2 8.x migrates the DESCRIPTION `RoxygenNote` field to
# `Config/roxygen2/version`. Two consequences broke checkhelper on the Fedora
# r-devel CRAN flavors:
#   1. `usethis::use_pipe()` (<= 3.2.1) checks `has_fields("RoxygenNote")` in
#      `uses_roxygen()`, so on an 8.x-documented package it aborts with
#      "does not use roxygen2" -- this is what failed test-find_missing_values.R.
#   2. audit_tags.R reimplements the roxygenise() pipeline via roxygen2
#      internals; a future roxygen2 change could break it silently.
# This file pins both invariants so the class of failure cannot creep back in.

test_that("create_example_pkg produces a roxygen2-managed package regardless of field migration", {
  skip_if_not_installed("usethis")
  skip_if_not_installed("attachment")

  path <- quiet_create_example_pkg()
  on.exit(unlink(dirname(path), recursive = TRUE), add = TRUE)

  d <- desc::desc(file.path(path, "DESCRIPTION"))

  if (packageVersion("roxygen2") >= "8.0.0") {
    # roxygen2 8.x records the version under Config/roxygen2/version and drops
    # the legacy RoxygenNote field. The example package must still be
    # recognisable as roxygen-managed through the new field.
    expect_true(d$has_fields("Config/roxygen2/version"))
  } else {
    expect_true(d$has_fields("RoxygenNote"))
  }
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
