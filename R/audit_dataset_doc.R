#' Audit dataset documentation
#'
#' Lists every dataset under `data/` and reports whether a roxygen
#' documentation file is found in `R/`. CRAN raises a NOTE for undocumented
#' datasets.
#'
#' @param pkg Path to the package to audit.
#'
#' @return A tibble with columns `name` and `has_doc`.
#' @export
#' @seealso [fix_dataset_doc()].
#' @examples
#' \dontrun{
#' audit_dataset_doc(".")
#' }
audit_dataset_doc <- function(pkg = ".") {
  data_dir <- file.path(pkg, "data")
  r_dir <- file.path(pkg, "R")

  if (!dir.exists(data_dir)) {
    out <- tibble::tibble(name = character(), has_doc = logical())
    cli::cli_inform(c("v" = "audit_dataset_doc(): no data/ directory."))
    return(out)
  }

  rda_files <- list.files(data_dir, pattern = "\\.(rda|RData|rdata)$",
                          ignore.case = TRUE)
  if (!length(rda_files)) {
    out <- tibble::tibble(name = character(), has_doc = logical())
    cli::cli_inform(c("v" = "audit_dataset_doc(): no datasets found."))
    return(out)
  }

  names <- tools::file_path_sans_ext(rda_files)

  r_files <- if (dir.exists(r_dir)) {
    list.files(r_dir, pattern = "\\.R$", full.names = TRUE)
  } else {
    character()
  }

  has_doc <- vapply(names, function(n) {
    if (!length(r_files)) { return(FALSE) }
    # Escape regex metacharacters: dataset names can contain `.` and other
    # symbols that would otherwise mis-match (e.g. `iris.setosa` would match
    # `irisXsetosa`).
    n_re <- escape_regex(n)
    pattern <- paste0("(^|[^[:alnum:]_])\"", n_re, "\"|@name\\s+", n_re, "\\b")
    any(vapply(r_files, function(f) {
      content <- paste(readLines(f, warn = FALSE), collapse = "\n")
      grepl(pattern, content, perl = TRUE)
    }, logical(1)))
  }, logical(1))

  out <- tibble::tibble(name = names, has_doc = unname(has_doc))

  n_missing <- sum(!out$has_doc)
  attr(out, "summary") <- sprintf(
    "%d dataset(s), %d undocumented", nrow(out), n_missing
  )

  cli::cli_inform(c(
    "i" = "audit_dataset_doc(): {nrow(out)} dataset{?s}, {n_missing} undocumented."
  ))

  out
}

#' Generate a roxygen skeleton for a dataset
#'
#' Writes `R/{prefix}{name}.R` with a roxygen documentation skeleton for the
#' `data/{name}.rda` dataset. Wraps [use_data_doc()].
#'
#' @param name Name of the dataset (without extension).
#' @param pkg Path to the package.
#' @param prefix Prefix for the generated R file. Defaults to `"doc_"`.
#' @param description Description shown in the roxygen block.
#' @param source Source attribution shown in the roxygen block.
#' @param overwrite If `FALSE` (default), error when the doc file already
#'   exists. Set `TRUE` to regenerate it in place.
#'
#' @return Invisibly, the path of the generated file.
#' @export
#' @seealso [audit_dataset_doc()], [use_data_doc()].
#' @examples
#' \dontrun{
#' fix_dataset_doc("my_data", description = "My data", source = "Internal")
#' }
fix_dataset_doc <- function(name,
                            pkg = ".",
                            prefix = "doc_",
                            description = "Description",
                            source = "Source",
                            overwrite = FALSE) {
  out <- withr::with_dir(pkg, {
    .use_data_doc(
      name = name,
      prefix = prefix,
      description = description,
      source = source,
      overwrite = overwrite
    )
  })

  abs_path <- normalizePath(file.path(pkg, out), mustWork = FALSE)

  cli::cli_inform(c(
    "v" = "fix_dataset_doc(): wrote {.file {abs_path}}."
  ))

  invisible(abs_path)
}


# Internal implementations ---------------------------------------------------

#' Escape characters that have special meaning in a regex.
#' @noRd
escape_regex <- function(x) {
  gsub("([][{}()+*^$|\\\\?.\\-])", "\\\\\\1", x, perl = TRUE)
}

#' Get information of an .rda file stored under data/.
#' @noRd
.get_data_info <- function(name, description, source) {
  if (!dir.exists("data")) {
    stop("'data/' folder does not exist, hence there is no data file to look for.")
  }
  # Escape `name` before embedding into the regex so a dataset name with
  # regex metacharacters (e.g. `iris.versicolor`) doesn't mis-match.
  name_re <- escape_regex(name)
  file <- list.files("data",
    pattern = glue::glue("^{name_re}\\.(rda|RData|rdata)$"),
    full.names = TRUE,
    ignore.case = TRUE
  )
  if (purrr::is_empty(file)) {
    stop("Data object was not found. It must be the name of one .rda in your 'data/' directory, without extension")
  } else if (length(file) > 1) {
    stop("There are multiple files with the same name")
  }
  dataset <- get(load(file))
  if (!is.data.frame(dataset)) {
    stop("The object stored in the Rda file must be a data.frame.",
         call. = FALSE)
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

#' Create documentation of a rda / RData dataset in a package.
#'
#' @importFrom glue glue
#' @noRd
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

  message(glue("Adding the data documentation in {path}"))
  invisible(path)
}
