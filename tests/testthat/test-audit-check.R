test_that("audit_check() exists with the expected signature", {
  expect_true(is.function(audit_check))
  expect_true(all(c("pkg", "check_output") %in% names(formals(audit_check))))
})

test_that("audit_check() summarises ERROR/WARNING/NOTE counts and returns the rcmdcheck result", {
  # Mock the heavy implementation so we test the wrapper's contract
  # (count summary + passthrough return) without paying the rcmdcheck
  # cost. The legacy rcmdcheck path is already exercised by
  # test-check_as_cran.R.
  fake <- list(
    errors   = "boom",
    warnings = c("w1", "w2"),
    notes    = c("n1", "n2", "n3")
  )
  testthat::local_mocked_bindings(.check_as_cran = function(...) fake)

  out <- expect_message(
    audit_check("."),
    regexp = "1 ERROR.*2 WARNING.*3 NOTE"
  )
  expect_identical(out, fake)
})

test_that("audit_check() handles the all-clean case (0/0/0) without choking on plurals", {
  fake <- list(errors = character(), warnings = character(), notes = character())
  testthat::local_mocked_bindings(.check_as_cran = function(...) fake)

  out <- expect_message(
    audit_check("."),
    regexp = "0 ERRORs.*0 WARNINGs.*0 NOTEs"
  )
  expect_identical(out, fake)
})
