#' Create documentation of a rda / RData dataset in a package
#'
#' @param name Name of your data without extension
#' @param prefix Add prefix for the name of the output R script
#' @param description Description of the dataset that will be added in the documentation
#' @param source Source of the dataset that will be presented in the documentation
#'
#' @return Creates a data documentation in a R file and returns path to the file
#'
#' @export
#'
#' @importFrom glue glue
#'
#' @seealso [get_data_info()] to only retrieve information without writing the documentation
#'
#' @examples
#' \dontrun{
#' # This adds a R file in the current user directory
#' # This works if there is a "my_data.rda" file in your "data/" directory
#' use_data_doc("my_data", description = "Description of my_data", source = "Here the source")
#' }
use_data_doc <- function(name, prefix = "doc_", description = "Description", source = "Source") {
  if (!dir.exists("R")) {
    dir.create("R")
  }
  if (!file.exists("DESCRIPTION")) {
    stop("There is no DESCRIPTION file. Are you sure to develop a R package ?")
  }

  path <- glue("R/{prefix}{name}.R")

  render_template(
    path_template = system.file("template", "data-doc.R", package = "checkhelper"),
    path_to_save = path,
    data = get_data_info(name, description, source)
  )

  if (!requireNamespace("cli")) {
    cli::cli_alert_success(
      glue("Adding the data documentation in {path}")
    )
    invisible(path)
  } else {
    message(
      glue("Adding the data documentation in {path}")
    )
    invisible(path)
  }
}
