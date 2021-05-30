path <- create_pkg()

test_that("find_missing_values works", {
  out <- expect_message(find_missing_values(path), "[my_long_fun_name_for_multiple_lines_globals, my_median]")
  expect_equal(nrow(out), 2)
  expect_equal(out$has_export, c(TRUE, TRUE))
  expect_equal(out$has_return, c(TRUE, FALSE))
  expect_equal(out$has_export_and_return_ok, c(FALSE, FALSE))
})

# Remove path
unlink(path, recursive = TRUE)
