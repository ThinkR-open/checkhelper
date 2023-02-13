#' Get infos form .Rdata inside data folder
#'
#' @param name name of file
#' @param description description for the data
#' @param source source of data
#'
#' @return list of infos form data
#' @export
#'
#' @examples
#' path_project <- tempfile(pattern = "data-")
#' path_data <- file.path(path_project, "data")
#' dir.create(path_data, recursive = TRUE)
#' path_rda <- file.path(path_data, "iris.rda")
#' save(iris, file = path_rda)
#' withr::with_dir(
#'   path_project, {
#'    get_data_info("iris", "Iris data frame", source = "ThinkR")
#'   })
#'
#' # Clean userspace
#' unlink(path_project, recursive = TRUE)
#'
get_data_info <- function(name, description, source) {
  if (!dir.exists("data/")) {
    stop("data folder doesn't exists")
  }
  file <- list.files("data/",
               pattern = glue::glue("^{name}\\.(r|R).+$"),
               full.names = TRUE)
  if(purrr::is_empty(file)){
    stop("Don't find this data object, must be the name of one .rda.")
  }else if(length(file) > 1){
    stop("Multiple files with the same name.")
  }
  dataset <- get(load(file))
  if (!is.data.frame(dataset)) {
    "Your object must be a data.frame."
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
