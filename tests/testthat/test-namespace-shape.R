## test-namespace-shape.R
##
## Lock the public API surface. Any add / remove / rename of an exported
## name must be accompanied by an update to the list below - the test fails
## otherwise.

expected_exports <- c(
  ## Public façades - audit_*
  "audit_ascii",
  "audit_check",
  "audit_citation",
  "audit_dataset_doc",
  "audit_description",
  "audit_dontrun",
  "audit_downloads",
  "audit_globals",
  "audit_tags",
  "audit_userspace",

  ## Public façades - fix_*
  "fix_ascii",
  "fix_dataset_doc",
  "fix_globals",

  ## Low-level tools (kept exported)
  "asciify_file",
  "asciify_r_source",
  "find_nonascii_tokens",
  "create_example_pkg",

  ## Deprecated wrappers (lifecycle::deprecate_warn at top of body)
  "asciify_pkg",
  "check_as_cran",
  "check_clean_userspace",
  "find_missing_tags",
  "find_nonascii_files",
  "get_data_info",
  "get_no_visible",
  "get_notes",
  "print_globals",
  "use_data_doc"
)

test_that("the NAMESPACE exports exactly the expected set", {
  actual <- sort(getNamespaceExports("checkhelper"))
  expected <- sort(expected_exports)
  expect_equal(actual, expected)
})
