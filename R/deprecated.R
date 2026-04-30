## Deprecated wrappers
##
## Each wrapper emits `lifecycle::deprecate_warn()` once per session and
## delegates to the renamed internal implementation (prefixed with a dot)
## so the new audit_* / fix_* façades can keep calling the same logic
## without re-triggering the deprecation warning.

#' Deprecated: use [audit_ascii()] instead
#' @keywords internal
#' @param path Path to the package to scan.
#' @param scope Subdirectories / files to scan, relative to `path`.
#' @param ignore_ext Extensions to skip (binary assets, snapshots).
#' @param size_limit Skip files larger than this many bytes.
#' @return See [audit_ascii()].
#' @export
find_nonascii_files <- function(path = ".",
                                scope = c("R", "tests", "vignettes", "man",
                                          "DESCRIPTION", "NAMESPACE"),
                                ignore_ext = c("png", "jpg", "jpeg", "gif",
                                                 "rds", "rda", "rdata",
                                                 "pdf", "ico", "svg"),
                                size_limit = 5e5) {
  lifecycle::deprecate_warn(
    "1.0.0",
    "find_nonascii_files()",
    "audit_ascii()"
  )
  .find_nonascii_files(
    path = path,
    scope = scope,
    ignore_ext = ignore_ext,
    size_limit = size_limit
  )
}

#' Deprecated: use [fix_ascii()] instead
#' @keywords internal
#' @param path Path to the package to rewrite.
#' @param scope Subdirectories to rewrite.
#' @param strategy Rewrite strategy (see [asciify_r_source()]).
#' @param identifiers What to do when a non-ASCII identifier is found.
#' @param dry_run If `TRUE` (default), only report what would change.
#' @return See [fix_ascii()].
#' @export
asciify_pkg <- function(path = ".",
                        scope = c("R", "tests", "vignettes"),
                        strategy = c("auto", "escape", "translit", "report"),
                        identifiers = c("error", "warn", "skip"),
                        dry_run = TRUE) {
  lifecycle::deprecate_warn(
    "1.0.0",
    "asciify_pkg()",
    "fix_ascii()"
  )
  .asciify_pkg(
    path = path,
    scope = scope,
    strategy = strategy,
    identifiers = identifiers,
    dry_run = dry_run
  )
}

#' Deprecated: internal helper used by [audit_globals()]
#' @keywords internal
#' @param path Path to package.
#' @param checks Output of [rcmdcheck::rcmdcheck()] if already computed.
#' @param ... Other parameters passed to [rcmdcheck::rcmdcheck()].
#' @return A tibble of notes from `R CMD check` containing global-related
#'   information.
#' @export
get_notes <- function(path = ".", checks, ...) {
  lifecycle::deprecate_warn(
    "1.0.0",
    "get_notes()",
    "audit_globals()"
  )
  if (missing(checks)) {
    .get_notes(path = path, ...)
  } else {
    .get_notes(path = path, checks = checks, ...)
  }
}

#' Deprecated: use [audit_globals()] instead
#' @keywords internal
#' @inheritParams get_notes
#' @return See [audit_globals()].
#' @export
get_no_visible <- function(path = ".", checks, ...) {
  lifecycle::deprecate_warn(
    "1.0.0",
    "get_no_visible()",
    "audit_globals()"
  )
  if (missing(checks)) {
    .get_no_visible(path = path, ...)
  } else {
    .get_no_visible(path = path, checks = checks, ...)
  }
}

#' Deprecated: use [fix_globals()] instead
#' @keywords internal
#' @param globals A list as issued from [get_no_visible()] or empty.
#' @param path Path to package.
#' @param ... Other parameters passed to [rcmdcheck::rcmdcheck()].
#' @param message Logical. Whether to return message with content (Default)
#'   or return as list.
#' @return See [fix_globals()].
#' @export
print_globals <- function(globals, path = ".", ..., message = TRUE) {
  lifecycle::deprecate_warn(
    "1.0.0",
    "print_globals()",
    "fix_globals()"
  )
  if (missing(globals)) {
    .print_globals(path = path, ..., message = message)
  } else {
    .print_globals(globals = globals, path = path, ..., message = message)
  }
}

#' Deprecated: use [audit_tags()] instead
#' @keywords internal
#' @inheritParams roxygen2::roxygenise
#' @return See [audit_tags()].
#' @export
find_missing_tags <- function(package.dir = ".",
                              roclets = NULL,
                              load_code = NULL,
                              clean = FALSE) {
  lifecycle::deprecate_warn(
    "1.0.0",
    "find_missing_tags()",
    "audit_tags()"
  )
  .find_missing_tags(
    package.dir = package.dir,
    roclets = roclets,
    load_code = load_code,
    clean = clean
  )
}

#' Deprecated: use [audit_check()] instead
#' @keywords internal
#' @inheritParams audit_check
#' @return See [audit_check()].
#' @export
check_as_cran <- function(pkg = ".",
                          check_output = file.path(
                            dirname(normalizePath(pkg, mustWork = FALSE)),
                            "check"
                          ),
                          scratch = tempfile("scratch_dir"),
                          Ncpus = 1,
                          as_command = FALSE,
                          clean_before = TRUE,
                          open = FALSE,
                          repos = getOption("repos")) {
  lifecycle::deprecate_warn(
    "1.0.0",
    "check_as_cran()",
    "audit_check()"
  )
  .check_as_cran(
    pkg = pkg,
    check_output = check_output,
    scratch = scratch,
    Ncpus = Ncpus,
    as_command = as_command,
    clean_before = clean_before,
    open = open,
    repos = repos
  )
}

#' Deprecated: use [audit_userspace()] instead
#' @keywords internal
#' @inheritParams audit_userspace
#' @return See [audit_userspace()].
#' @export
check_clean_userspace <- function(pkg = ".",
                                  check_output = tempfile("dircheck")) {
  lifecycle::deprecate_warn(
    "1.0.0",
    "check_clean_userspace()",
    "audit_userspace()"
  )
  .check_clean_userspace(pkg = pkg, check_output = check_output)
}

#' Deprecated: internal helper used by [fix_dataset_doc()]
#' @keywords internal
#' @param name Name of the file that exists in `data/`.
#' @param description Description for the data.
#' @param source Source of data.
#' @return A list of information from a data.frame.
#' @export
get_data_info <- function(name, description, source) {
  lifecycle::deprecate_warn(
    "1.0.0",
    "get_data_info()",
    "fix_dataset_doc()"
  )
  .get_data_info(name = name, description = description, source = source)
}

#' Deprecated: use [fix_dataset_doc()] instead
#' @keywords internal
#' @param name Name of the dataset (without extension).
#' @param prefix Prefix for the generated R file.
#' @param description Description shown in the roxygen block.
#' @param source Source attribution shown in the roxygen block.
#' @param overwrite If `FALSE` (default), error when the doc file already
#'   exists.
#' @return Invisibly, the path of the generated file.
#' @export
use_data_doc <- function(name,
                         prefix = "doc_",
                         description = "Description",
                         source = "Source",
                         overwrite = FALSE) {
  lifecycle::deprecate_warn(
    "1.0.0",
    "use_data_doc()",
    "fix_dataset_doc()"
  )
  .use_data_doc(
    name = name,
    prefix = prefix,
    description = description,
    source = source,
    overwrite = overwrite
  )
}
