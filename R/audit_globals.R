#' Audit globals to declare in R/globals.R
#'
#' Runs `R CMD check` on the package and extracts every
#' `no visible binding for global variable` and `no visible global function`
#' note. Use [fix_globals()] to print or write the corresponding
#' `globalVariables()` block. Wraps [get_no_visible()].
#'
#' @param pkg Path to the package to audit.
#'
#' @return A list with two tibbles, `globalVariables` and `functions`,
#'   or `NULL` if the package has no global notes.
#' @export
#' @seealso [fix_globals()], [get_no_visible()].
#' @examples
#' \dontrun{
#' pkg <- create_example_pkg()
#' audit_globals(pkg)
#' }
audit_globals <- function(pkg = ".") {
  out <- .get_no_visible(path = pkg)

  if (is.null(out)) {
    cli::cli_inform(c("v" = "audit_globals(): no global notes detected."))
    return(out)
  }

  n_vars <- nrow(out[["globalVariables"]])
  n_funs <- nrow(out[["functions"]])

  cli::cli_inform(c(
    "i" = "audit_globals(): {n_vars} global variable{?s}, {n_funs} global function call{?s}."
  ))

  out
}

#' Print or write the globalVariables block to declare
#'
#' Convenience wrapper that runs the audit, then either prints the
#' `globalVariables(...)` block to console (default) or writes it to
#' `R/globals.R`. Wraps [print_globals()].
#'
#' @param pkg Path to the package.
#' @param write If `TRUE`, **overwrite** `<pkg>/R/globals.R` with a
#'   single `globalVariables(...)` call. Default `FALSE` (print the
#'   block to the console for manual paste).
#'
#' @return Invisibly, the path written (when `write = TRUE`) or `NULL`.
#' @export
#' @seealso [audit_globals()], [print_globals()].
#' @examples
#' \dontrun{
#' pkg <- create_example_pkg()
#' fix_globals(pkg)
#' fix_globals(pkg, write = TRUE)
#' }
fix_globals <- function(pkg = ".", write = FALSE) {
  globals <- .get_no_visible(path = pkg)

  if (is.null(globals)) {
    cli::cli_inform(c("v" = "fix_globals(): no globals to declare."))
    return(invisible(NULL))
  }

  printed <- .print_globals(globals = globals, message = FALSE)

  if (!isTRUE(write)) {
    message(printed[["liste_funs"]])
    message(printed[["liste_globals"]])
    cli::cli_inform(c(
      "i" = "fix_globals(): paste the block above into R/globals.R, or call fix_globals(write = TRUE)."
    ))
    return(invisible(NULL))
  }

  globals_path <- file.path(pkg, "R", "globals.R")
  if (!dir.exists(dirname(globals_path))) {
    dir.create(dirname(globals_path), recursive = TRUE)
  }

  writeLines(printed[["liste_globals_code"]], globals_path)
  cli::cli_inform(c(
    "v" = "fix_globals(): wrote globalVariables block to {.file {globals_path}}."
  ))

  invisible(globals_path)
}


# Internal implementations ---------------------------------------------------

#' List notes from check and identify global variables.
#'
#' @importFrom rcmdcheck rcmdcheck
#' @importFrom dplyr mutate tibble
#' @importFrom stringr str_extract str_extract_all
#' @noRd
.get_notes <- function(path = ".", checks, ...) {
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
    stringr::str_replace_all("\\u2019\\n", "\\u2019RETURN") %>%
    stringr::str_replace_all("\\u0027\\n", "\\u0027RETURN") %>%
    stringr::str_replace_all("NOTE\\n", "NOTERETURN") %>%
    stringr::str_replace_all("importFrom", "RETURN importFrom") %>%
    stringr::str_replace_all("to your NAMESPACE file", "RETURN to your NAMESPACE file") %>%
    stringr::str_replace_all("\\s*\\n\\s*", " ")

  res <- tibble(notes = strsplit(notes_with_globals_return, "RETURN")[[1]]) %>%
    mutate(
      filepath = str_extract(notes, "(\\s*\\(.*\\)\\s*){0,1}"),
      filepath = ifelse(filepath == "", "-", filepath),
      fun = purrr::map2_chr(notes, filepath, ~ gsub(.y, "", .x, fixed = TRUE)),
      fun = str_extract(fun, ".+(?=:)"),
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

#' List no visible globals from check and separate by category.
#'
#' @importFrom dplyr filter select mutate left_join rename
#' @noRd
.get_no_visible <- function(path = ".", checks, ...) {
  if (missing(checks)) {
    notes <- .get_notes(path, ...)
  } else {
    notes <- .get_notes(path, checks, ...)
  }
  if (is.null(notes)) {
    return(NULL)
  }

  proposed <- notes %>%
    filter(is_importfrom) %>%
    select(notes, importfrom_function) %>%
    rename(proposed = notes)

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

#' Print no visible globals from check and separate by category.
#'
#' @importFrom dplyr pull mutate group_by summarise
#' @importFrom glue glue_collapse glue
#' @noRd
.print_globals <- function(globals, path = ".", ..., message = TRUE) {
  if (missing(globals)) {
    globals <- .get_no_visible(path, ...)
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

  globals_body <- globals[["globalVariables"]] %>%
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
    paste(., collapse = ", \n")

  # File-clean payload: a single `utils::globalVariables(...)` call.
  # Safe to write verbatim into R/globals.R.
  liste_globals_code <- paste0(
    "utils::globalVariables(unique(c(\n", globals_body, "\n)))"
  )

  # Display payload: same code wrapped in human-readable banners. Used
  # when `fix_globals(write = FALSE)` prints to the console.
  liste_globals <- paste0(
    "--- Potential GlobalVariables ---\n",
    "-- code to copy to your R/globals.R file --\n\n",
    liste_globals_code
  )

  if (isTRUE(message)) {
    message(glue(liste_funs, "\n", liste_globals))
  } else {
    list(
      liste_funs = liste_funs,
      liste_globals = liste_globals,
      liste_globals_code = liste_globals_code
    )
  }
}
