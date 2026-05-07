#' Audit globals to declare in R/globals.R
#'
#' Runs `R CMD check` on the package and extracts every
#' `no visible binding for global variable` and `no visible global function`
#' note. Use [fix_globals()] to print or write the corresponding
#' `globalVariables()` block. Wraps [get_no_visible()].
#'
#' @param pkg Path to the package to audit.
#' @param checks Optional. A pre-computed [rcmdcheck::rcmdcheck()] result
#'   (a list with at least a `notes` element). When supplied, `audit_globals()`
#'   reuses it instead of re-running `R CMD check` on `pkg`. Useful to share
#'   a single check between [audit_globals()] and [fix_globals()].
#'
#' @return A list with three tibbles, `globalVariables`, `functions`
#'   and `operators`, or `NULL` if the package has no global notes.
#'   `globalVariables` collects names that need a
#'   `utils::globalVariables()` declaration; `functions` collects
#'   external functions to import via `@importFrom`; `operators`
#'   collects NSE tokens / data.table / rlang pronouns (`:=`,
#'   `.SD`, `.data`, `!!`, …) that also need `@importFrom` rather
#'   than a `globalVariables()` entry.
#' @export
#' @seealso [fix_globals()], [get_no_visible()].
#' @examples
#' \dontrun{
#' pkg <- create_example_pkg()
#'
#' # One-shot:
#' audit_globals(pkg)
#'
#' # Shared check (avoid running R CMD check twice):
#' chk <- rcmdcheck::rcmdcheck(pkg)
#' audit_globals(pkg, checks = chk)
#' fix_globals(pkg, checks = chk)
#' }
audit_globals <- function(pkg = ".", checks = NULL) {
  out <- if (is.null(checks)) {
    .get_no_visible(path = pkg)
  } else {
    .get_no_visible(path = pkg, checks = checks)
  }

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
#' @param write If `TRUE`, write a single `globalVariables(...)` call
#'   to `<pkg>/R/globals.R`, **merging** with whatever names that file
#'   already declares (the freshly detected names are added on top of
#'   the existing ones, deduplicated). Default `FALSE` (print the
#'   block to the console for manual paste).
#' @param checks Optional. A pre-computed [rcmdcheck::rcmdcheck()] result
#'   (a list with at least a `notes` element). When supplied, `fix_globals()`
#'   reuses it instead of re-running `R CMD check` on `pkg`. Useful to share
#'   a single check between [audit_globals()] and [fix_globals()].
#'
#' @return Invisibly, the path written (when `write = TRUE`) or `NULL`.
#' @export
#' @seealso [audit_globals()], [print_globals()].
#' @examples
#' \dontrun{
#' pkg <- create_example_pkg()
#' fix_globals(pkg)
#' fix_globals(pkg, write = TRUE)
#'
#' # Reuse a single R CMD check across both audit and fix:
#' chk <- rcmdcheck::rcmdcheck(pkg)
#' audit_globals(pkg, checks = chk)
#' fix_globals(pkg, checks = chk, write = TRUE)
#' }
fix_globals <- function(pkg = ".", write = FALSE, checks = NULL) {
  globals <- if (is.null(checks)) {
    .get_no_visible(path = pkg)
  } else {
    .get_no_visible(path = pkg, checks = checks)
  }

  if (is.null(globals)) {
    cli::cli_inform(c("v" = "fix_globals(): no globals to declare."))
    return(invisible(NULL))
  }

  printed <- .print_globals(globals = globals, message = FALSE)

  has_operators <- nzchar(printed[["liste_operators"]])

  if (!isTRUE(write)) {
    message(printed[["liste_funs"]])
    message(printed[["liste_globals"]])
    if (has_operators) {
      message(printed[["liste_operators"]])
    }
    # Two destinations: the globalVariables block goes to
    # R/globals.R; the operators / pronouns block goes to a roxygen
    # `@importFrom` somewhere in the package (any R file). Keep the
    # two cli messages separate so the user does not paste NAMESPACE
    # concerns into globals.R.
    cli::cli_inform(c(
      "i" = "fix_globals(): paste the `utils::globalVariables(...)` block above into R/globals.R, or call fix_globals(write = TRUE)."
    ))
    if (has_operators) {
      cli::cli_inform(c(
        "i" = "fix_globals(): paste the operators / pronouns `@importFrom` lines into a roxygen block in any R file (e.g. R/utils-imports.R), NOT into R/globals.R."
      ))
    }
    return(invisible(NULL))
  }

  globals_path <- file.path(pkg, "R", "globals.R")
  if (!dir.exists(dirname(globals_path))) {
    dir.create(dirname(globals_path), recursive = TRUE)
  }

  # Merge with whatever the file already declared. R CMD check filters
  # out names already covered by an existing globalVariables() call,
  # so by the time fix_globals() runs the second time, the new notes
  # only list *uncovered* names. Overwriting would erase the curated
  # set and re-flag those names on the very next check — a circular
  # game the user can never win.
  preserved <- extract_existing_globals(globals_path)
  merged_block <- merge_globals_block(printed[["liste_globals_code"]], preserved)

  writeLines(merged_block, globals_path)
  cli::cli_inform(c(
    "v" = "fix_globals(): wrote globalVariables block to {.file {globals_path}} (merged with {length(preserved)} previously declared name{?s})."
  ))
  # Operators / pronouns must NOT go into R/globals.R because they are
  # exports from another package, not undeclared variables. Surface the
  # @importFrom suggestions on stdout so the user can wire them into
  # NAMESPACE explicitly.
  if (has_operators) {
    message(printed[["liste_operators"]])
    cli::cli_inform(c(
      "i" = "fix_globals(): operators / pronouns above need an `@importFrom` line, NOT a globalVariables() entry — see operators section."
    ))
  }

  invisible(globals_path)
}


# Internal implementations ---------------------------------------------------

#' Tokens that R CMD check flags as "no visible global ..." but that are
#' actually exports from another package - the right fix is `@importFrom`,
#' not a `globalVariables()` entry. Each token maps to the candidate
#' source package(s); when more than one applies (`:=` is exported by
#' both data.table and rlang), `.print_globals()` lists every candidate
#' so the user picks one consciously.
#'
#' @noRd
.known_operators <- list(
  ":="     = c("data.table", "rlang"),
  ".SD"    = "data.table",
  ".N"     = "data.table",
  ".I"     = "data.table",
  ".GRP"   = "data.table",
  ".BY"    = "data.table",
  ".EACHI" = "data.table",
  ".data"  = "rlang",
  ".env"   = "rlang",
  "!!"     = "rlang",
  "!!!"    = "rlang"
)

#' Extract the names already declared by `globalVariables()` calls in
#' an existing `R/globals.R`. Returns `character(0)` when the file
#' doesn't exist or doesn't parse.
#'
#' @noRd
extract_existing_globals <- function(globals_path) {
  if (!file.exists(globals_path)) {
    return(character(0))
  }
  exprs <- tryCatch(parse(file = globals_path), error = function(e) NULL)
  if (is.null(exprs)) {
    return(character(0))
  }
  out <- character(0)
  for (i in seq_along(exprs)) {
    e <- exprs[[i]]
    if (!is_globalVariables_call(e)) {
      next
    }
    # Guard against `utils::globalVariables()` with no arguments
    # (length(e) == 1 is just the function symbol itself). Without
    # this guard `e[[2]]` raises subscript out of bounds and aborts
    # the whole `fix_globals(write = TRUE)` pass on a degenerate
    # but otherwise legal `globals.R`.
    if (length(e) < 2L) {
      next
    }
    out <- c(out, collect_string_literals(e[[2]]))
  }
  unique(out)
}

#' Recursively collect every character-literal leaf of an unevaluated R
#' expression. Used by `extract_existing_globals()` to read the names
#' from an existing `R/globals.R` without ever calling `eval()` on the
#' file's contents — the historic `eval(arg, envir = safe_env)` ran
#' under `baseenv()` (which exposes `system()`, `library()`, `file()`,
#' …), so a crafted `globals.R` could execute arbitrary code at
#' `fix_globals(write = TRUE)` time.
#'
#' Symbols, numerics, logicals, `NULL`, and arbitrary calls
#' (`system(...)`, `c(...)`, `unique(...)`) are walked through but
#' never evaluated; only quoted character literals are returned.
#' @noRd
collect_string_literals <- function(expr) {
  if (is.character(expr) && length(expr) >= 1L) {
    return(as.character(expr))
  }
  if (is.call(expr)) {
    out <- character(0)
    for (i in seq_along(expr)) {
      out <- c(out, collect_string_literals(expr[[i]]))
    }
    return(out)
  }
  character(0)
}

#' TRUE when `e` is a call to `globalVariables()` or
#' `utils::globalVariables()`.
#' @noRd
is_globalVariables_call <- function(e) {
  if (!is.call(e)) {
    return(FALSE)
  }
  fn <- e[[1]]
  if (is.name(fn) && identical(fn, as.name("globalVariables"))) {
    return(TRUE)
  }
  if (is.call(fn) && length(fn) == 3 &&
        identical(fn[[1]], as.name("::")) &&
        identical(fn[[2]], as.name("utils")) &&
        identical(fn[[3]], as.name("globalVariables"))) {
    return(TRUE)
  }
  FALSE
}

#' Inject the previously-declared names into the freshly generated
#' `globalVariables(unique(c(...)))` block so that the rewrite is a
#' superset of the existing declarations.
#'
#' @param fresh_block character(1), the block produced by
#'   `.print_globals()$liste_globals_code`. Always wrapped in
#'   `unique(c(...))` so duplicates are harmless.
#' @param preserved character vector of names parsed from the
#'   existing `globals.R` (may be empty).
#' @noRd
merge_globals_block <- function(fresh_block, preserved) {
  if (length(preserved) == 0L) {
    return(fresh_block)
  }
  preserved <- sort(unique(preserved))
  preserved_chunk <- paste0(
    "# previously declared:\n",
    paste0("\"", preserved, "\"", collapse = ", ")
  )
  # When R CMD check surfaces only function notes, the fresh block's
  # `c()` body is empty (`utils::globalVariables(unique(c(\n\n)))`).
  # Naively prepending a `,` then injecting yields `c(, "a", "b")`,
  # which parses but errors at eval with "argument 1 is empty".
  # Detect the empty-body shape and rebuild from scratch.
  is_empty_body <- grepl(
    "utils::globalVariables\\(unique\\(c\\(\\s*\\n\\s*\\n\\s*\\)\\)\\)$",
    fresh_block
  )
  if (is_empty_body) {
    return(paste0(
      "utils::globalVariables(unique(c(\n",
      preserved_chunk,
      "\n)))"
    ))
  }
  # Inject just before the final closing `)))`.
  sub(
    "\n\\)\\)\\)$",
    paste0(", \n", preserved_chunk, "\n)))"),
    fresh_block
  )
}

#' List notes from check and identify global variables.
#'
#' @importFrom rcmdcheck rcmdcheck
#' @importFrom dplyr mutate tibble
#' @importFrom stringr str_extract str_extract_all
#' @noRd
.get_notes <- function(path = ".", checks,
                       build_args = "--no-build-vignettes",
                       args = c(
                         "--no-manual", "--no-tests",
                         "--no-examples", "--no-vignettes"
                       ),
                       ...) {
  # The globals notes ("no visible binding for global variable",
  # "no visible global function definition") come from R CMD check's
  # static `* checking R code for possible problems` step. They do
  # not depend on building vignettes, running tests, running
  # examples, or rendering the manual. Skipping those four phases
  # turns audit_globals() / fix_globals() from a multi-minute call on
  # vignette-heavy packages into a few seconds. Caller can still
  # override via `build_args` / `args` if needed.
  if (missing(checks)) {
    checks <- rcmdcheck(
      path = path,
      build_args = build_args,
      args = args,
      ...
    )
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
      # Anchored, non-colon match: capture only up to the *first*
      # colon. The historical greedy `.+(?=:)` would happily eat past
      # the colon for e.g. ":=" notes (`fn: no visible global function
      # definition for ':='`), capturing the entire prose of the note
      # as the function name and breaking the operators-import path.
      fun = str_extract(fun, "^[^:]+(?=:)"),
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
    left_join(proposed, by = c("variable" = "importfrom_function")) %>%
    mutate(is_operator = variable %in% names(.known_operators))

  # Operators / pronouns (`:=`, `.data`, `.SD`, `!!`, ...) get their own
  # bucket. They will be rendered as `@importFrom <pkg> <token>`
  # suggestions, never as `globalVariables()` entries (which would be
  # semantically wrong: they are not undeclared variables, they are
  # exports from another package).
  ops_tbl <- fun_names %>%
    filter(is_operator) %>%
    select(fun, variable) %>%
    mutate(source_pkg = vapply(
      variable,
      function(v) paste(.known_operators[[v]], collapse = ";"),
      character(1)
    ))

  list(
    globalVariables = fun_names %>%
      filter(is_global_variable & !is_operator) %>%
      select(-is_operator),
    functions = fun_names %>%
      filter(is_function & !is_operator) %>%
      select(-is_operator),
    operators = ops_tbl
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

  required_keys <- c("globalVariables", "functions")
  if (!is.list(globals) || !all(required_keys %in% names(globals))) {
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

  liste_operators <- format_operators_section(globals[["operators"]])

  if (isTRUE(message)) {
    message(glue(liste_funs, "\n", liste_globals, "\n", liste_operators))
  } else {
    list(
      liste_funs = liste_funs,
      liste_globals = liste_globals,
      liste_globals_code = liste_globals_code,
      liste_operators = liste_operators
    )
  }
}

#' Format the third section of `.print_globals()` output: a set of
#' `@importFrom` lines for the operators / pronouns surfaced by
#' `.get_no_visible()`. When a token is exported by more than one
#' candidate package (currently only `:=` from data.table OR rlang),
#' every candidate is listed and the user picks one consciously — no
#' silent guessing.
#' @noRd
format_operators_section <- function(operators) {
  if (is.null(operators) || nrow(operators) == 0L) {
    return("")
  }

  uniq <- operators[!duplicated(operators$variable), c("variable", "source_pkg")]
  is_ambiguous <- grepl(";", uniq$source_pkg, fixed = TRUE)

  unambiguous_lines <- character(0)
  if (any(!is_ambiguous)) {
    unamb <- uniq[!is_ambiguous, , drop = FALSE]
    by_pkg <- split(unamb$variable, unamb$source_pkg)
    unambiguous_lines <- vapply(
      names(by_pkg),
      function(pkg) {
        toks <- sort(unique(by_pkg[[pkg]]))
        paste0("#' @importFrom ", pkg, " ", paste(toks, collapse = " "))
      },
      character(1)
    )
  }

  ambiguous_lines <- character(0)
  if (any(is_ambiguous)) {
    amb <- uniq[is_ambiguous, , drop = FALSE]
    for (i in seq_len(nrow(amb))) {
      sym <- amb$variable[i]
      candidates <- strsplit(amb$source_pkg[i], ";", fixed = TRUE)[[1]]
      # `# #'` would be invisible to roxygen2 — pasting verbatim
       # gives the user zero @importFrom declared. Emit the lines as
       # real `#'` and add a `# KEEP ONE:` banner so the user knows
       # to delete every other line.
      ambiguous_lines <- c(
        ambiguous_lines,
        sprintf(
          "# `%s` is exported by %s - KEEP ONE of the lines below, delete the other:",
          sym,
          paste0("'", candidates, "'", collapse = " or ")
        ),
        vapply(
          candidates,
          function(pkg) paste0("#' @importFrom ", pkg, " ", sym),
          character(1)
        )
      )
    }
  }

  # Banners are `#`-prefixed so the whole block survives a verbatim
  # paste into an R file. Bare `--- ... ---` would parse-error.
  paste(c(
    "# --- Operators / pronouns to import via NAMESPACE ---",
    "# --- add to an R file (e.g. R/utils-imports.R) ---",
    "",
    unambiguous_lines,
    ambiguous_lines,
    "NULL"
  ), collapse = "\n")
}
