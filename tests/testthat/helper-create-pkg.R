create_pkg <- function() {
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
  return(path)
}
