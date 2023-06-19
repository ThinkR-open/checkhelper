#' List notes from check and identify global variables
#'
#' @inheritParams rcmdcheck::rcmdcheck
#' @param checks Output of \code{\link[rcmdcheck]{rcmdcheck}} if already computed
#' @param ... Other parameters for \code{\link[rcmdcheck]{rcmdcheck}}
#'
#' @importFrom rcmdcheck rcmdcheck
#' @importFrom dplyr mutate tibble
#' @importFrom stringr str_extract str_extract_all
#'
#' @return A tibble with notes and information about the global variables
#'
#' @export
#' @examples
#' \dontrun{
#' # This runs a check of the example package
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
get_notes <- function(path = ".", checks, ...) {
  if (missing(checks)) {
    checks <- rcmdcheck(path = path, ...)
  }

  if (length(checks[["notes"]]) == 0) {
    return(NULL)
  }

  notes_with_globals <- checks[["notes"]][grep("no visible global|no visible binding", checks[["notes"]])]

  if (length(notes_with_globals) == 0) {
    return(NULL)
  }

  notes_with_globals_return <- notes_with_globals %>%
    stringr::str_replace_all("\\u2019\\n", "\\u2019RETURN") %>% # tick after variable
    stringr::str_replace_all("\\u0027\\n", "\\u0027RETURN") %>% # other tick after variable
    stringr::str_replace_all("NOTE\\n", "NOTERETURN") %>% # After NOTE
    stringr::str_replace_all("importFrom", "RETURN importFrom") %>% # Before importFrom
    stringr::str_replace_all("to your NAMESPACE file", "RETURN to your NAMESPACE file") %>% # After importFrom
    stringr::str_replace_all("\\s*\\n\\s*", " ") # No known new line

  res <- tibble(notes = strsplit(notes_with_globals_return, "RETURN")[[1]]) %>%
    # pull(res[2,1])
    # res <- tibble(notes = strsplit(notes_with_globals, "\n")[[1]]) %>%
    mutate(
      # Maybe a path in parenthesis ?
      filepath = str_extract(notes, "(\\s*\\(.*\\)\\s*){0,1}"),
      filepath = ifelse(filepath == "", "-", filepath),
      fun = purrr::map2_chr(notes, filepath, ~ gsub(.y, "", .x, fixed = TRUE)),
      fun = str_extract(fun, ".+(?=:)"),
      # fun = str_extract(notes, "(\\s*\\(.*\\)\\s){0,1}.+(?=:)"),
      is_function = grepl("no visible global function definition", notes),
      is_global_variable = grepl("no visible binding for global variable", notes),
      variable = str_extract(notes, "(?<=\\u2018).+(?=\\u2019)|(?<=\\u0027).+(?=\\u0027)"),
      is_importfrom = grepl("importFrom", notes)
    )

  tmp <- str_extract_all(res$notes, "(?<=\")(\\w*\\.*\\_*)*(?=\")", simplify = TRUE)
  if (ncol(tmp) >= 2) {
    importfrom_function <- tmp[, 2]
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
#' @return A list with no visible globals
#'
#' @export
#' @examples
#' \dontrun{
#' # This runs a check of the example package
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
get_no_visible <- function(path = ".", checks, ...) {
  if (missing(checks)) {
    notes <- get_notes(path, ...)
  } else {
    notes <- get_notes(path, checks, ...)
  }
  if (is.null(notes)) {
    return(NULL)
  }

  # propositions
  proposed <- notes %>%
    filter(is_importfrom) %>%
    select(notes, importfrom_function) %>%
    rename(proposed = notes)

  # join with names
  fun_names <- notes %>%
    filter(is_global_variable | is_function) %>%
    select(-importfrom_function, -is_importfrom) %>%
    left_join(proposed, by = c("variable" = "importfrom_function"))

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
#' @param message Logical. Whether to return message with content (Default) or return as list
#' @inheritParams rcmdcheck::rcmdcheck
#' @inheritParams get_notes
#'
#' @importFrom dplyr pull mutate group_by summarise
#' @importFrom glue glue_collapse glue
#'
#' @return A message with no visible globals or a list with no visible globals
#'
#' @export
#' @examples
#' \dontrun{
#' # This runs a check of the example package
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
#' ggplot2::ggplot() +
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
print_globals <- function(globals, path = ".", ..., message = TRUE) {
  if (missing(globals)) {
    globals <- get_no_visible(path, ...)
  }
  if (is.null(globals)) {
    if (isTRUE(message)) {
      message("There is no globalVariable detected.")
      return(invisible())
    } else {
      return(NULL)
    }
  }

  if (!isTRUE(is.list(globals) & length(globals) == 2)) {
    stop("globals should be a list as issued from 'get_no_visible()' or empty")
  }

  liste_funs <- globals[["functions"]] %>%
    group_by(fun) %>%
    summarise(
      text = paste(
        variable %>%
          unique() %>%
          sort(),
        collapse = ", "
      )
    ) %>%
    mutate(
      text = paste0(fun, ": ", text, "\n")
    ) %>%
    pull(text) %>%
    paste(., collapse = "") %>%
    paste0("--- Functions to add in NAMESPACE (with @importFrom ?) ---\n\n", .)

  liste_globals <- globals[["globalVariables"]] %>%
    group_by(fun) %>%
    summarise(
      text = paste(
        variable %>%
          unique() %>%
          sort() %>%
          paste0("\"", ., "\""),
        collapse = ", "
      )
    ) %>%
    mutate(
      text = paste0("# ", fun, ": \n", text)
    ) %>%
    pull(text) %>%
    paste(., collapse = ", \n") %>%
    paste0(
      "--- Potential GlobalVariables ---\n",
      "-- code to copy to your R/globals.R file --\n\n",
      "globalVariables(unique(c(\n", ., "\n)))"
    )

  if (isTRUE(message)) {
    message(glue(liste_funs, "\n", liste_globals))
  } else {
    list(
      liste_funs = liste_funs,
      liste_globals = liste_globals
    )
  }
}
