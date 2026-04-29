test_that("audit_userspace() exists with the expected signature", {
  expect_true(is.function(audit_userspace))
  expect_named(formals(audit_userspace), c("pkg", "check_output"))
})

test_that("audit_userspace() emits a cli message (smoke)", {
  skip_on_cran()
  skip_on_ci()
  path <- suppressWarnings(create_example_pkg())
  on.exit(unlink(path, recursive = TRUE))
  expect_message(
    suppressWarnings(audit_userspace(path)),
    regexp = "userspace|files|check"
  )
})
