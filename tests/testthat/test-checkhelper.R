# Warnings are ok with new version o
path <- suppressWarnings(create_pkg())

# get_no_visible ----
# Get globals
# globals <- get_no_visible(path, quiet = TRUE)

# Not in this R session
# if (FALSE) {
# command <- paste0(
#   Sys.getenv("R_HOME"), "/bin/Rscript -e '",
#   # 'print("ok")',
#   'globals <- checkhelper::get_no_visible("', normalizePath(path), '", quiet = TRUE); ',
#   'saveRDS(globals,"', normalizePath(file.path(tempdir, "checkpackage", "globals.rds"), mustWork = FALSE), '")',
#   "'"
# )
# fileR <- tempfile(fileext = ".R")
# cat(command, file = fileR)
# file.edit(fileR)
# glue::glue(command)
# system(command)
# # get globals output
# globals <- readRDS(file.path(tempdir, "checkpackage", "globals.rds"))
# }

# withr::local_environment({
  # test_env({
  globals <- checkhelper::get_no_visible(path, quiet = TRUE)
  # saveRDS(globals,"C:\\Users\\seb44\\AppData\\Local\\Temp\\RtmpqI9biW\\checkpackage\\globals.rds")
# })

test_that("get_no_visible works", {
  # glue("\"", paste(globals$globalVariables$fun, collapse = "\", \""), "\"")
  expect_equal(globals$globalVariables$fun,
               c(rep("my_long_fun_name_for_multiple_lines_globals", 3),
                 rep("my_plot", 3), rep("my_plot_rdname", 3)))
  # glue("\"", paste(globals$globalVariables$variable, collapse = "\", \""), "\"")
  expect_equal(globals$globalVariables$variable,
               c("x", "y", "new_col", "x", "y", "new_col2", "x", "y", "new_col2"))
})

# print_globals ----
# Print globals to copy-paste
print_outputs <- print_globals(globals, message = FALSE)

test_that("print_outputs works", {
  expect_equal(
    print_outputs$liste_funs,
    "--- Functions to add in NAMESPACE (with @importFrom ?) ---\n\nmy_long_fun_name_for_multiple_lines_globals: %>%, aes, geom_point, ggplot, mutate\nmy_plot: %>%, aes, geom_point, ggplot, mutate\nmy_plot_rdname: %>%, aes, geom_point, ggplot, mutate\n"
  )
  expect_equal(
    print_outputs$liste_globals,
    "--- Potential GlobalVariables ---\n-- code to copy to your R/globals.R file --\n\nglobalVariables(unique(c(\n# my_long_fun_name_for_multiple_lines_globals: \n\"new_col\", \"x\", \"y\", \n# my_plot: \n\"new_col2\", \"x\", \"y\", \n# my_plot_rdname: \n\"new_col2\", \"x\", \"y\"\n)))"
  )
  expect_message(print_globals(globals, message = TRUE))
})

# Remove path
unlink(path, recursive = TRUE)

# Test when no notes at all ----
path <- create_pkg(with_functions = FALSE, with_extra_notes = FALSE)
globals <- get_no_visible(path, quiet = TRUE)
print_outputs <- print_globals(globals, message = FALSE)

test_that("no notes works", {
  expect_null(globals)
  expect_null(print_outputs)
  expect_message(print_globals(globals, message = TRUE), "no globalVariable")
})

unlink(path, recursive = TRUE)


# Test when only extra notes ----
path <- create_pkg(with_functions = FALSE, with_extra_notes = TRUE)
notes <- get_notes(path = path)

test_that("extra notes only works", {
  expect_null(notes)
})

unlink(path, recursive = TRUE)

# Test when checks done before ----
path <- suppressWarnings(create_pkg())
checks <- rcmdcheck::rcmdcheck(path = path, quiet = TRUE)
notes <- get_notes(path = path, checks = checks)

test_that("notes from checks works", {
  expect_equal(nrow(notes), 26)
  expect_equal(ncol(notes), 7)
  expect_true(all(notes[["fun"]][2:9] == "my_long_fun_name_for_multiple_lines_globals"))
  expect_true(all(notes[["fun"]][10:17] == "my_plot"))
  expect_true(all(notes[["fun"]][18:25] == "my_plot_rdname"))
  expect_true(all(notes[["is_global_variable"]][c(6:8, 14:16)]))
})

globals <- get_no_visible(path, checks, quiet = TRUE)

test_that("get_no_visible works after checks", {
  # glue("\"", paste(globals$globalVariables$fun, collapse = "\", \""), "\"")
  expect_equal(globals$globalVariables$fun,
               c(rep("my_long_fun_name_for_multiple_lines_globals", 3),
                 rep("my_plot", 3), rep("my_plot_rdname", 3)))
  # glue("\"", paste(globals$globalVariables$variable, collapse = "\", \""), "\"")
  expect_equal(globals$globalVariables$variable,
               c("x", "y", "new_col", "x", "y", "new_col2", "x", "y", "new_col2"))
})

# Remove path
unlink(path, recursive = TRUE)
