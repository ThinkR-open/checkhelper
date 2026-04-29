#' Create documentation of a rda / RData dataset in a package
#'
#' @param name Name of your data without extension
#' @param prefix Add prefix for the name of the output R script
#' @param description Description of the dataset that will be added in the documentation
#' @param source Source of the dataset that will be presented in the documentation
#' @param overwrite Logical. If `FALSE` (default) and the target documentation
#'   file already exists, the function errors out instead of silently
#'   replacing the user's edits. Set to `TRUE` to regenerate the file
#'   in place (#19).
#'
#' @return Creates a data documentation in a R file and returns path to the file
#'
#' @noRd
#'
#' @importFrom glue glue
.use_data_doc <- function(name,
                         prefix = "doc_",
                         description = "Description",
                         source = "Source",
                         overwrite = FALSE) {
  if (!dir.exists("R")) {
    dir.create("R")
  }
  if (!file.exists("DESCRIPTION")) {
    stop("There is no DESCRIPTION file. Are you sure to develop a R package ?")
  }

  path <- as.character(glue("R/{prefix}{name}.R"))

  if (file.exists(path) && !isTRUE(overwrite)) {
    stop(
      "Documentation file already exists: ", path, ".\n",
      "Pass `overwrite = TRUE` to regenerate it.",
      call. = FALSE
    )
  }

  render_template(
    path_template = system.file("template", "data-doc.R", package = "checkhelper"),
    path_to_save = path,
    data = .get_data_info(name, description, source)
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
