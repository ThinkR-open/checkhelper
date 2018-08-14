#' List global variables from check
#'
#' @importFrom rcmdcheck rcmdcheck
ch_list_globals <- function() {
  checks <- rcmdcheck::rcmdcheck()
  grep("no visible binding for global variable", checks$warnings)
}
