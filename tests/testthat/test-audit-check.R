test_that("audit_check() exists with the expected signature", {
  expect_true(is.function(audit_check))
  expect_true(all(c("pkg", "check_output") %in% names(formals(audit_check))))
})
