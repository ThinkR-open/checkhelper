#' Documentation of .rda in package
#'
#' @param name Name of your data. only the name,
#' @param prefix Add prefix for the name of R script
#' @param description Add a description
#' @param source Add a source
#'
#' @return Create a data documentation and return path to the file
#'
#' @export
#'
#' @importFrom glue glue
#'
#' @examples
#' \dontrun{
#' use_data_doc("my_data", description = "Desc of my_data", source = "Here my source")
#' }
use_data_doc <- function(name, prefix = "doc_", description = "Description", source = "Source") {
  if (!file.exists("DESCRIPTION") & dir.exists("R")) {
    stop("You have to be in package.")
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
