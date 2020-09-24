# Create fake package ----
tempdir <- tempdir()
# Create fake package
usethis::create_package(file.path(tempdir, "checkpackage"), open = FALSE)
# on.exit(unlink(file.path(tempdir, "checkpackage"), recursive = TRUE))

# Create function no visible global variables and missing documented functions
cat("
#' Function
#' @importFrom dplyr filter
#' @export
my_fun <- function(data) {
  data %>%
  filter(col == 3) %>%
  mutate(new_col = 1) %>%
  ggplot() +
    aes(x, y, colour = new_col) +
    geom_point()
}

#' Function 2
#' @export
my_median <- function() {
  data %>%
  filter(col == 3) %>%
  mutate(new_col2 = 1) %>%
  ggplot() +
    aes(x, y, colour = new_col2) +
    geom_point()
}
", file = file.path(tempdir, "checkpackage", "R", "function.R"))

path <- file.path(tempdir, "checkpackage")
attachment::att_amend_desc(path = path)

# get_no_visible ----
# Get globals
globals <- get_no_visible(path, quiet = TRUE)

test_that("get_no_visible works", {
  # glue("\"", paste(globals$globalVariables$fun, collapse = "\", \""), "\"")
  expect_equal(globals$globalVariables$fun,
               c("my_fun", "my_fun", "my_fun",
                 "my_median", "my_median", "my_median", "my_median"))
  # glue("\"", paste(globals$globalVariables$variable, collapse = "\", \""), "\"")
  expect_equal(globals$globalVariables$variable,
               c("x", "y", "new_col", "data", "x", "y", "new_col2"))
})

# print_globals ----
# Print globals to copy-paste
print_outputs <- print_globals(globals, message = FALSE)

test_that("print_outputs works", {
  expect_equal(
    print_outputs$liste_funs,
    "--- Fonctions to add in NAMESPACE (with @importFrom ?) ---\n\nmy_fun: %>%, aes, geom_point, ggplot, mutate\nmy_median: %>%, aes, geom_point, ggplot, mutate\n"
  )
  expect_equal(
    print_outputs$liste_globals,
    "--- Potential GlobalVariables ---\n-- code to copy to your globals.R file --\n\nglobalVariables(c(unique(\n# my_fun: \n\"new_col\", \"x\", \"y\", \n# my_median: \n\"data\", \"new_col2\", \"x\", \"y\"\n)))"
  )
  expect_message(print_globals(globals, message = TRUE))
})

# check no notes ----
file.remove(file.path(tempdir, "checkpackage", "R", "function.R"))

globals <- get_no_visible(path, quiet = TRUE)
print_outputs <- print_globals(globals, message = FALSE)

test_that("no notes works", {
  expect_null(globals)
  expect_null(print_outputs)
  expect_message(print_globals(globals, message = TRUE))
})
