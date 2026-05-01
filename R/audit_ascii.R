#' Audit non-ASCII characters in a package
#'
#' Lists every line containing non-ASCII bytes across the package files.
#' CRAN raises a NOTE when source code or documentation contains non-ASCII
#' characters that are not properly escaped. Wraps [find_nonascii_files()].
#'
#' @param pkg Path to the package to audit.
#' @param scope Character vector of subdirectories / files to scan.
#' @param ignore_ext Extensions to skip (binary assets, snapshots).
#' @param size_limit Skip files larger than this many bytes.
#'
#' @return A data frame with columns `file`, `line`, `text`, `n_tokens`.
#' @export
#' @seealso [fix_ascii()] to apply the rewrite, [find_nonascii_files()].
#' @examples
#' \dontrun{
#' pkg <- create_example_pkg()
#' audit_ascii(pkg)
#' }
audit_ascii <- function(pkg = ".",
                        scope = c("R", "tests", "vignettes", "man",
                                  "DESCRIPTION", "NAMESPACE"),
                        ignore_ext = c("png", "jpg", "jpeg", "gif",
                                       "rds", "rda", "rdata",
                                       "pdf", "ico", "svg"),
                        size_limit = 5e5) {
  out <- .find_nonascii_files(
    path = pkg,
    scope = scope,
    ignore_ext = ignore_ext,
    size_limit = size_limit
  )

  out <- tibble::as_tibble(out)

  n_files <- length(unique(out$file))
  n_lines <- nrow(out)

  attr(out, "summary") <- sprintf(
    "%d non-ASCII line(s) across %d file(s)", n_lines, n_files
  )

  cli::cli_inform(c(
    "i" = "audit_ascii(): {n_lines} non-ASCII line{?s} across {n_files} file{?s}."
  ))

  out
}

#' Rewrite non-ASCII characters in a package
#'
#' Escapes non-ASCII string literals to `\uXXXX` and transliterates
#' comments / roxygen so the package passes CRAN's "non-ASCII characters"
#' check. Dry-run by default: pass `dry_run = FALSE` to actually rewrite
#' files. Wraps [asciify_pkg()].
#'
#' @param pkg Path to the package to rewrite.
#' @param scope Subdirectories to rewrite.
#' @param strategy Rewrite strategy (see [asciify_r_source()]).
#' @param identifiers What to do when a non-ASCII identifier is found.
#' @param dry_run If `TRUE` (default), only report what would change.
#'
#' @return Invisibly, a data frame of the changes per file.
#' @export
#' @seealso [audit_ascii()], [asciify_pkg()].
#' @examples
#' \dontrun{
#' pkg <- create_example_pkg()
#' fix_ascii(pkg, dry_run = TRUE)
#' }
fix_ascii <- function(pkg = ".",
                      scope = c("R", "tests", "vignettes"),
                      strategy = c("auto", "escape", "translit", "report"),
                      identifiers = c("error", "warn", "skip"),
                      dry_run = TRUE) {
  strategy <- match.arg(strategy)
  identifiers <- match.arg(identifiers)

  out <- .asciify_pkg(
    path = pkg,
    scope = scope,
    strategy = strategy,
    identifiers = identifiers,
    dry_run = dry_run
  )

  n_changed <- if (is.null(out)) { 0L } else { sum(out$changed, na.rm = TRUE) }
  verb <- if (isTRUE(dry_run)) { "would rewrite" } else { "rewrote" }

  cli::cli_inform(c(
    "i" = "fix_ascii(): {verb} {n_changed} file{?s} (non-ASCII)."
  ))

  invisible(out)
}
