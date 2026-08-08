path <- quiet_create_example_pkg()
withr::defer(unlink(path, recursive = TRUE), teardown_env())

test_that("audit_tags() exists and accepts pkg = path", {
  local_quiet()
  expect_true(is.function(audit_tags))
  expect_named(formals(audit_tags), c("pkg"))
})

test_that("audit_tags() returns the same 3-element list as find_missing_tags()", {
  local_quiet_deprecation()
  local_quiet()
  out <- suppressMessages(suppressWarnings(audit_tags(path)))
  expect_type(out, "list")
  expect_named(out, c("package_doc", "data", "functions"))
})

test_that("audit_tags() emits a cli message summarising the audit", {
  local_quiet()
  expect_message(
    suppressWarnings(audit_tags(path)),
    regexp = "tag"
  )
})
