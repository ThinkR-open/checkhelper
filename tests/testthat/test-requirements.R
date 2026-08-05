test_that("roxygen2 is recent enough for the audit-tags test expectations", {
  # The test suite branches on roxygen2 behaviour at the 7.3.0 boundary
  # (>= 7.3.0 emits messages, older versions emitted warnings) and is
  # validated against the roxygen2 8.x line, on which checkhelper is now
  # supported (see test-roxygen2-8x-compat.R). Anything older than 7.3.0 is
  # untested and would break the message/warning expectations, so fail early
  # with a clear signal rather than deep inside an audit-tags assertion.
  expect_true(
    packageVersion("roxygen2") >= "7.3.0",
    info = "checkhelper's tests require roxygen2 >= 7.3.0"
  )
})
