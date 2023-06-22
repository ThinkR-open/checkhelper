#' Get information of a .Rda file stored inside the 'data/' folder
#'
#' @param name name of the file that exists in "data/"
#' @param description description for the data
#' @param source source of data
#'
#' @return list of information from a data.frame
#' @export
#'
#' @seealso [use_data_doc()] to add the information directly as roxygen documentation in your package.
#'
#' @examples
#' # Store a dataset as rda file
#' path_project <- tempfile(pattern = "data-")
#' path_data <- file.path(path_project, "data")
#' dir.create(path_data, recursive = TRUE)
#' path_rda <- file.path(path_data, "iris.rda")
#' save(iris, file = path_rda)
#'
#' # Get its information
#' withr::with_dir(
#'   path_project,
#'   {
#'     get_data_info("iris", "Iris data frame", source = "ThinkR")
#'   }
#' )
#'
#' # Clean userspace
#' unlink(path_project, recursive = TRUE)
#'
get_data_info <- function(name, description, source) {
  if (!dir.exists("data")) {
    stop("'data/' folder does not exist, hence there is no data file to look for.")
  }
  file <- list.files("data",
    pattern = glue::glue("^{name}\\.(r|R).+$"),
    full.names = TRUE
  )
  if (purrr::is_empty(file)) {
    stop("Data object was not found. It must be the name of one .rda in your 'data/' directory, without extension")
  } else if (length(file) > 1) {
    stop("There are multiple files with the same name")
  }
  dataset <- get(load(file))
  if (!is.data.frame(dataset)) {
    "The object stored in the Rda file must be a data.frame."
  }
  info <- lapply(names(dataset), function(x) {
    list(name = x, class = class(dataset[[x]]))
  })
  list(
    name = name,
    description = description,
    rows = nrow(dataset),
    cols = ncol(dataset),
    items = info,
    source = source
  )
}
