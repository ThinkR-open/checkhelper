
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
