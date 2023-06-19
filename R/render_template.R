#' Render template for data documentation
#'
#' This use double stash template.
#'
#' @param path path to the template.
#' @param data list of information to replace in the template.
#'
#' @return use for this side effect. Make a file
#' @noRd
render_template <- function(path_template, path_to_save, data) {
  render <- whisker::whisker.render(readLines(path_template, encoding = "UTF-8", warn = FALSE), data)
  writeLines(render, con = path_to_save)
}
