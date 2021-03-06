#' @param with_functions Logical. Whether there will be functions or not (with notes)
#' @param with_extra_notes Logical. Whether there are extra notes or not
create_pkg <- function(with_functions = TRUE, with_extra_notes = FALSE) {
  # Create fake package ----
  pkg_path <- tempfile(pattern = "pkg-")
  dir.create(pkg_path)
  # Create fake package
  usethis::create_package(file.path(pkg_path, "checkpackage"), open = FALSE)
  # on.exit(unlink(file.path(pkg_path, "checkpackage"), recursive = TRUE))

  if (isTRUE(with_extra_notes)) {
    extra_dir_path <- file.path(pkg_path, "checkpackage", "inst", "I build", "a very", "long_name",
                                "that should be",
                                "not_ok", "for_checks",
                                "and hopefully", "lead to", "some", "extra_notes")
    dir.create(extra_dir_path, recursive = TRUE)
    cat("for extra notes",
        file = file.path(extra_dir_path, "super_long_file_name_for_tests_to_extra_notes"))
  }

  if (isTRUE(with_functions)) {
    # Create function no visible global variables and missing documented functions
    cat("
#' Function
#' @importFrom dplyr filter
#' @return
#' @export
my_long_fun_name_for_multiple_lines_globals <- function(data) {
  data %>%
  filter(col == 3) %>%
  mutate(new_col = 1) %>%
  ggplot() +
    aes(x, y, colour = new_col) +
    geom_point()
}

#' Function 2
#' @return GGplot for data
#' @export
my_plot <- function(data) {
  data %>%
  filter(col == 3) %>%
  mutate(new_col2 = 1) %>%
  ggplot() +
    aes(x, y, colour = new_col2) +
    geom_point()
}

#' Function not exported but with doc
my_not_exported_doc <- function() {
  message('Not exported but with title, should have @noRd')
}

#' Function not exported but with doc
#' @noRd
my_not_exported_nord <- function() {
  message('Not exported but with title, and @noRd ok')
}

my_not_exported_nodoc <- function() {
  message('Not exported but with no roxygen')
}

#' Function 3 with rdname
#' @rdname my_plot
#' @export
my_plot_rdname <- function(data) {
  data %>%
  filter(col == 3) %>%
  mutate(new_col2 = 1) %>%
  ggplot() +
    aes(x, y, colour = new_col2) +
    geom_point()
}
", file = file.path(pkg_path, "checkpackage", "R", "function.R"))

  }

  path <- file.path(pkg_path, "checkpackage")
  attachment::att_amend_desc(path = path)
  return(path)
}
