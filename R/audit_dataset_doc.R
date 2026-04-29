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
    if (!length(r_files)) return(FALSE)
    pattern <- paste0("(^|[^[:alnum:]_])\"", n, "\"|@name\\s+", n, "\\b")
    any(vapply(r_files, function(f) {
      content <- paste(readLines(f, warn = FALSE), collapse = "\n")
      grepl(pattern, content, perl = TRUE)
    }, logical(1)))
  }, logical(1))

  out <- tibble::tibble(name = names, has_doc = unname(has_doc))

  n_missing <- sum(!out$has_doc)
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
    use_data_doc(
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
