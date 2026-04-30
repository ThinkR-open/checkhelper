#' Render template for data documentation
#'
#' This use double stash template.
#'
#' @param path_template path to the template.
#' @param path_to_save path where the rendered file is written.
#' @param data list of information to replace in the template.
#'
#' @return Used for the side effect of writing `path_to_save`.
#' @noRd
render_template <- function(path_template, path_to_save, data) {
  render <- whisker::whisker.render(readLines(path_template, encoding = "UTF-8", warn = FALSE), data)
  writeLines(render, con = path_to_save)
}
