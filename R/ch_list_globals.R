#' List notes from check and identify global variables
#'
#' @inheritParams rcmdcheck::rcmdcheck
#' @param ... Other parameters for \code{\link[rcmdcheck]{rcmdcheck}}
#'
#' @importFrom rcmdcheck rcmdcheck
#' @importFrom dplyr mutate tibble
#' @importFrom stringr str_extract str_extract_all
#'
#' @export
#' @examples
#' \dontrun{
#' tempdir <- tempdir()
#' # Create fake package
#' usethis::create_package(file.path(tempdir, "checkpackage"), open = FALSE)
#'
#' # Create function no visible global variables and missing documented functions
#' cat("
#' #' Function
#' #' @importFrom dplyr filter
#' #' @export
#' my_fun <- function() {
#' data %>%
#' filter(col == 3) %>%
#' mutate(new_col = 1) %>%
#' ggplot() +
#'   aes(x, y, colour = new_col) +
#'   geom_point()
#' }
#' ", file = file.path(tempdir, "checkpackage", "R", "function.R"))
#'
#' path <- file.path(tempdir, "checkpackage")
#' attachment::att_to_description(path = path)
#' get_notes(path)
#' }

get_notes <- function(path = ".", ...) {

  checks <- rcmdcheck(path = path, ...)

  res <- tibble(notes = strsplit(checks[["notes"]], "\n")[[1]]) %>%
    mutate(
      fun = str_extract(notes, ".+(?=:)"),
      is_function = grepl("no visible global function definition", notes),
      is_global_variable = grepl("no visible binding for global variable", notes),
      variable = str_extract(notes, "(?<=\\u2018).+(?=\\u2019)"),
      is_importfrom = grepl("importFrom", notes)
    )

    tmp <- str_extract_all(res$notes, "(?<=\")(\\w*\\.*\\_*)*(?=\")", simplify = TRUE)
    if (ncol(tmp) >= 2) {
      importfrom_function <- tmp[,2]
    } else {
      importfrom_function <- rep("", nrow(tmp))
    }

    res$importfrom_function <- importfrom_function
    return(res)
}

#' List no visible globals from check and separate by category
#'
#' @inheritParams rcmdcheck::rcmdcheck
#' @inheritParams get_notes
#'
#' @importFrom dplyr filter select mutate left_join rename
#'
#' @export
#' @examples
#' \dontrun{
#' tempdir <- tempdir()
#' # Create fake package
#' usethis::create_package(file.path(tempdir, "checkpackage"), open = FALSE)
#'
#' # Create function no visible global variables and missing documented functions
#' cat("
#' #' Function
#' #' @importFrom dplyr filter
#' #' @export
#' my_fun <- function() {
#' data %>%
#' filter(col == 3) %>%
#' mutate(new_col = 1) %>%
#' ggplot() +
#'   aes(x, y, colour = new_col) +
#'   geom_point()
#' }
#' ", file = file.path(tempdir, "checkpackage", "R", "function.R"))
#'
#' path <- file.path(tempdir, "checkpackage")
#' attachment::att_to_description(path = path)
#' get_no_visible(path)
#' }

get_no_visible <- function(path = ".", ...) {

  notes <- get_notes(path, ...)

  # propositions
  proposed <- notes %>%
    filter(is_importfrom) %>%
    select(notes, importfrom_function) %>%
    rename(proposed = notes)

  # join with names
  fun_names <- notes %>%
    filter(is_global_variable|is_function) %>%
    select(-importfrom_function, -is_importfrom) %>%
    left_join(proposed, by = c("variable"  = "importfrom_function"))

  list(
    globalVariables = fun_names %>%
      filter(is_global_variable),
    functions = fun_names %>%
      filter(is_function)
  )
}

#' Print no visible globals from check and separate by category
#'
#' @param globals A list as issued from \code{\link{get_no_visible}} or empty
#' @inheritParams rcmdcheck::rcmdcheck
#' @inheritParams get_notes
#'
#' @importFrom dplyr pull
#' @importFrom glue glue_collapse glue
#'
#' @export
#' @examples
#' \dontrun{
#' tempdir <- tempdir()
#' # Create fake package
#' usethis::create_package(file.path(tempdir, "checkpackage"), open = FALSE)
#'
#' # Create function no visible global variables and missing documented functions
#' cat("
#' #' Function
#' #' @importFrom dplyr filter
#' #' @export
#' my_fun <- function() {
#' data %>%
#' filter(col == 3) %>%
#' mutate(new_col = 1) %>%
#' ggplot() +
#'   aes(x, y, colour = new_col) +
#'   geom_point()
#' }
#' ", file = file.path(tempdir, "checkpackage", "R", "function.R"))
#'
#' path <- file.path(tempdir, "checkpackage")
#' attachment::att_to_description(path = path)
#' globals <- get_no_visible(path)
#' print_globals(globals = globals)
#' }

print_globals <- function(globals, path = ".", ...) {

  if (missing(globals)) {globals <- get_no_visible(path, ...)}

  if (!isTRUE(is.list(globals) & length(globals) == 2)) {
    stop("globals should be a list as issued from 'get_no_visible()' or empty")
  }

  print(glue("--- Fonctions to add in NAMESPACE ---\n\n"))
  print(glue_collapse(
    globals[["functions"]] %>%
      pull(variable) %>%
      unique() %>%
      sort(),
    sep = ", ")
  )

  print(glue("\n\n--- Potential GlobalVariables ---\n\n"))
  print(glue_collapse(
    c("globalVariables(", "c(",
      paste0(
        globals[["globalVariables"]] %>%
          pull(variable) %>%
          unique() %>% paste0("\"", ., "\""),
        collapse = ", "),
      ")", ")"),
    sep = "\n"))
}
