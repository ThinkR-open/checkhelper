path <- create_pkg()

test_that("find_missing_tags works", {
  out <- expect_message(find_missing_tags(path))
  expect_equal(nrow(out), 4)
  expect_equal(out$filename, rep("function.R", 4))
  expect_equal(out$topic, c("my_long_fun_name_for_multiple_lines_globals", "my_plot",
                            "my_not_exported_doc", "my_not_exported_nord"))
  expect_false("my_not_exported_nodoc" %in% out$topic)
  expect_equal(out$has_export, c(TRUE, TRUE, FALSE, FALSE))
  expect_equal(out$has_return, c(TRUE, TRUE, FALSE, FALSE))
  expect_equal(out$has_nord, c(FALSE, FALSE, FALSE, TRUE))
  expect_equal(out$test_has_export_and_return, c("not_ok", "ok", "ok", "ok"))
  expect_equal(out$test_has_export_or_has_nord, c("ok", "ok", "not_ok", "ok"))
})

# Remove path
unlink(path, recursive = TRUE)
