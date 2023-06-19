# Warnings are ok with new version o
path <- suppressWarnings(create_example_pkg())

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
globals <- get_no_visible(path, quiet = TRUE, args = c("--no-manual", "--as-cran"))
# saveRDS(globals, "~/Bureau/globals.rds")
# })

test_that("get_no_visible works", {
  # glue("\"", paste(globals$globalVariables$fun, collapse = "\", \""), "\"")
  expect_equal(
    globals$globalVariables$fun,
    c(
      rep("my_long_fun_name_for_multiple_lines_globals", 3),
      rep("my_plot", 3), rep("my_plot_rdname", 3)
    )
  )
  # glue("\"", paste(globals$globalVariables$variable, collapse = "\", \""), "\"")
  expect_equal(
    globals$globalVariables$variable,
    c("x", "y", "new_col", "x", "y", "new_col2", "x", "y", "new_col2")
  )
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
path <- create_example_pkg(with_functions = FALSE, with_extra_notes = FALSE)
globals <- get_no_visible(path, quiet = TRUE, args = c("--no-manual", "--as-cran"))
print_outputs <- print_globals(globals, message = FALSE)

test_that("no notes works", {
  expect_null(globals)
  expect_null(print_outputs)
  expect_message(print_globals(globals, message = TRUE), "no globalVariable")
})

unlink(path, recursive = TRUE)


# Test when only extra notes ----
path <- create_example_pkg(with_functions = FALSE, with_extra_notes = TRUE)
notes <- get_notes(path = path, args = c("--no-manual", "--as-cran"))

test_that("extra notes only works", {
  expect_null(notes)
})

unlink(path, recursive = TRUE)

# Test when checks done before ----
path <- suppressWarnings(create_example_pkg())
checks <- rcmdcheck::rcmdcheck(path = path, quiet = TRUE, args = c("--no-manual", "--as-cran"))
notes <- get_notes(path = path, checks = checks)

test_that("notes from checks works", {
  expect_equal(nrow(notes), 26)
  expect_equal(ncol(notes), 8)
  expect_true(all(notes[["fun"]][2:9] == "my_long_fun_name_for_multiple_lines_globals"))
  expect_true(all(notes[["fun"]][10:17] == "my_plot"))
  expect_true(all(notes[["fun"]][18:25] == "my_plot_rdname"))
  expect_true(all(notes[["is_global_variable"]][c(6:8, 14:16)]))
})

globals <- get_no_visible(path, checks, quiet = TRUE)

test_that("get_no_visible works after checks", {
  # glue("\"", paste(globals$globalVariables$fun, collapse = "\", \""), "\"")
  expect_equal(
    globals$globalVariables$fun,
    c(
      rep("my_long_fun_name_for_multiple_lines_globals", 3),
      rep("my_plot", 3), rep("my_plot_rdname", 3)
    )
  )
  # glue("\"", paste(globals$globalVariables$variable, collapse = "\", \""), "\"")
  expect_equal(
    globals$globalVariables$variable,
    c("x", "y", "new_col", "x", "y", "new_col2", "x", "y", "new_col2")
  )
})

# Remove path
unlink(path, recursive = TRUE)

# Detect path if exists in notes ----
# "  (/tmp/RtmpkW3scz/working_dir/RtmpMNu2An/file348c18e5542c/checkpackage.R
# x[1]: check/00_pkg_src/checkpackage/R/function.R:7-12) my_long_fun_name_for_mult
# x[1]: iple_lines_globals"

test_that("Check with path in outputs works", {
  notes_with_globals <-
    "checking R code for possible problems ... NOTE\nmy_long_fun_name_for_multiple_lines_globals: no visible global function\n  definition for ‘%>%’\nmy_long_fun_name_for_multiple_lines_globals: no visible global function\n  definition for ‘mutate’\nmy_long_fun_name_for_multiple_lines_globals: no visible global function\n  definition for ‘ggplot’\nmy_long_fun_name_for_multiple_lines_globals: no visible global function\n  definition for ‘aes’\nmy_long_fun_name_for_multiple_lines_globals: no visible binding for\n  global variable ‘x’\nmy_long_fun_name_for_multiple_lines_globals: no visible binding for\n  global variable ‘y’\nmy_long_fun_name_for_multiple_lines_globals: no visible binding for\n  global variable ‘new_col’\nmy_long_fun_name_for_multiple_lines_globals: no visible global function\n  definition for ‘geom_point’\nmy_plot: no visible global function definition for ‘%>%’\nmy_plot: no visible global function definition for ‘mutate’\nmy_plot: no visible global function definition for ‘ggplot’\nmy_plot: no visible global function definition for ‘aes’\nmy_plot: no visible binding for global variable ‘x’\nmy_plot: no visible binding for global variable ‘y’\nmy_plot: no visible binding for global variable ‘new_col2’\nmy_plot: no visible global function definition for ‘geom_point’\nmy_plot_rdname: no visible global function definition for ‘%>%’\nmy_plot_rdname: no visible global function definition for ‘mutate’\nmy_plot_rdname: no visible global function definition for ‘ggplot’\nmy_plot_rdname: no visible global function definition for ‘aes’\nmy_plot_rdname: no visible binding for global variable ‘x’\nmy_plot_rdname: no visible binding for global variable ‘y’\nmy_plot_rdname: no visible binding for global variable ‘new_col2’\nmy_plot_rdname: no visible global function definition for ‘geom_point’\nUndefined global functions or variables:\n  %>% aes geom_point ggplot mutate new_col new_col2 x y"

  fake_check <- list()
  fake_check[["notes"]] <- notes_with_globals

  res <- get_notes(checks = fake_check)

  expect_true(all(res[["filepath"]] == "-"))
  expect_equal(
    res[["fun"]],
    c(
      NA,
      rep("my_long_fun_name_for_multiple_lines_globals", 8),
      rep("my_plot", 8), rep("my_plot_rdname", 8),
      "Undefined global functions or variables"
    )
  )

  notes_with_globals_with_path <-
    "checking R code for possible problems ... NOTE\n  (/tmp/RtmpkW3scz/working_dir/RtmpMNu2An/file348c18e5542c/checkpackage.Rcheck/00_pkg_src/checkpackage/R/function.R:7-12) my_long_fun_name_for_multiple_lines_globals: no visible global function\n  definition for ‘%>%’\nmy_long_fun_name_for_multiple_lines_globals: no visible global function\n  definition for ‘mutate’\nmy_long_fun_name_for_multiple_lines_globals: no visible global function\n  definition for ‘ggplot’\nmy_long_fun_name_for_multiple_lines_globals: no visible global function\n  definition for ‘aes’\nmy_long_fun_name_for_multiple_lines_globals: no visible binding for\n  global variable ‘x’\nmy_long_fun_name_for_multiple_lines_globals: no visible binding for\n  global variable ‘y’\nmy_long_fun_name_for_multiple_lines_globals: no visible binding for\n  global variable ‘new_col’\nmy_long_fun_name_for_multiple_lines_globals: no visible global function\n  definition for ‘geom_point’\nmy_plot: no visible global function definition for ‘%>%’\nmy_plot: no visible global function definition for ‘mutate’\nmy_plot: no visible global function definition for ‘ggplot’\nmy_plot: no visible global function definition for ‘aes’\nmy_plot: no visible binding for global variable ‘x’\nmy_plot: no visible binding for global variable ‘y’\nmy_plot: no visible binding for global variable ‘new_col2’\nmy_plot: no visible global function definition for ‘geom_point’\nmy_plot_rdname: no visible global function definition for ‘%>%’\nmy_plot_rdname: no visible global function definition for ‘mutate’\nmy_plot_rdname: no visible global function definition for ‘ggplot’\nmy_plot_rdname: no visible global function definition for ‘aes’\nmy_plot_rdname: no visible binding for global variable ‘x’\nmy_plot_rdname: no visible binding for global variable ‘y’\nmy_plot_rdname: no visible binding for global variable ‘new_col2’\nmy_plot_rdname: no visible global function definition for ‘geom_point’\nUndefined global functions or variables:\n  %>% aes geom_point ggplot mutate new_col new_col2 x y"

  fake_check <- list()
  fake_check[["notes"]] <- notes_with_globals_with_path

  res <- get_notes(checks = fake_check)

  expect_true(all(res[["filepath"]][-2] == "-"))
  expect_true(res[["filepath"]][2] == "  (/tmp/RtmpkW3scz/working_dir/RtmpMNu2An/file348c18e5542c/checkpackage.Rcheck/00_pkg_src/checkpackage/R/function.R:7-12) ")
  expect_equal(
    res[["fun"]],
    c(
      NA,
      rep("my_long_fun_name_for_multiple_lines_globals", 8),
      rep("my_plot", 8), rep("my_plot_rdname", 8),
      "Undefined global functions or variables"
    )
  )
})
