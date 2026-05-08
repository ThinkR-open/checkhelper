#' Audit calls to known download / network functions
#'
#' CRAN policy: package code that downloads files or hits the network
#' at install / runtime must degrade gracefully when the network is
#' unavailable (offline build farms, sandboxed CI, locked-down user
#' environment). Common rejection causes: downloads from inside
#' `.onLoad()`, `.onAttach()`, vignettes or examples that have no
#' `tryCatch()` / `skip_if_offline()` / `\dontrun{}` guard.
#'
#' `audit_downloads()` walks `R/`, `tests/`, `vignettes/` and `inst/`
#' and surfaces every call to a known download or HTTP function so
#' the dev can review each one. Detection is purely static: each file
#' is parsed and the AST is walked; nothing is sourced.
#'
#' @param pkg Path to the package to audit.
#'
#' @return A tibble with columns `file`, `line`, `function` and
#'   `suggestion`. Empty when no download call is found, or when the
#'   package has none of the watched directories.
#' @export
#' @examples
#' \dontrun{
#' audit_downloads(".")
#' }
audit_downloads <- function(pkg = ".") {
  empty <- tibble::tibble(
    file = character(0),
    line = integer(0),
    `function` = character(0),
    suggestion = character(0)
  )

  files <- .download_audit_files(pkg)
  if (length(files) == 0L) {
    cli::cli_inform(c(
      "i" = "audit_downloads(): no R / tests / vignettes / inst content under {.path {pkg}}."
    ))
    return(empty)
  }

  hits <- do.call(rbind, lapply(files, .scan_one_file_for_downloads))
  if (is.null(hits) || nrow(hits) == 0L) {
    cli::cli_inform(c(
      "v" = "audit_downloads(): no download / network call detected."
    ))
    return(empty)
  }

  hits$file <- .relative_to_pkg(paths = hits$file, pkg = pkg)
  out <- tibble::as_tibble(hits)

  cli::cli_inform(c(
    "i" = "audit_downloads(): {nrow(out)} download / network call{?s} found across {length(unique(out$file))} file{?s}."
  ))

  out
}

# Internal implementation ----------------------------------------------------

#' Functions that hit the network. The set is conservative: every
#' entry below either downloads bytes from a URL or performs an HTTP
#' request. Non-HTTP I/O (`readLines(con = url(...))`, dynamic
#' `data.table::fread(URL)`) is intentionally not in scope here -
#' deciding whether a call is networked or local needs runtime
#' information static analysis cannot see.
#' @noRd
.known_download_functions <- c(
  # base / utils
  "download.file",
  "utils::download.file",
  "download.packages",
  "utils::download.packages",
  # httr
  "httr::GET",
  "httr::POST",
  "httr::PUT",
  "httr::PATCH",
  "httr::DELETE",
  "httr::HEAD",
  # httr2
  "httr2::req_perform",
  "httr2::req_perform_parallel",
  "httr2::req_perform_iterative",
  # curl
  "curl::curl_download",
  "curl::curl_fetch_memory",
  "curl::curl_fetch_disk",
  "curl::curl_fetch_stream",
  # RCurl (legacy but still on CRAN)
  "RCurl::getURL",
  "RCurl::getURI",
  "RCurl::getBinaryURL"
)

#' Render `paths` relative to `pkg` without any regex involvement
#' (handles Windows backslashes and pkg names with regex
#' metacharacters such as `.`).
#' @noRd
.relative_to_pkg <- function(paths, pkg) {
  norm_pkg <- normalizePath(pkg, winslash = "/", mustWork = FALSE)
  norm_pkg <- sub("/+$", "", norm_pkg)
  norm_paths <- normalizePath(paths, winslash = "/", mustWork = FALSE)
  prefix <- paste0(norm_pkg, "/")
  vapply(
    norm_paths,
    function(p) {
      if (startsWith(p, prefix)) {
        substring(p, first = nchar(prefix) + 1L)
      } else {
        p
      }
    },
    FUN.VALUE = character(1L),
    USE.NAMES = FALSE
  )
}

#' List every `.R` / `.Rmd` / `.Rnw` / `.qmd` file under the watched
#' directories of the package. Lowercase variants of each extension
#' are also matched.
#' @noRd
.download_audit_files <- function(pkg) {
  dirs <- file.path(pkg, c("R", "tests", "vignettes", "inst"))
  dirs <- dirs[dir.exists(dirs)]
  if (length(dirs) == 0L) {
    return(character(0))
  }
  list.files(
    dirs,
    pattern = "\\.(R|r|Rmd|rmd|Rnw|rnw|qmd)$",
    recursive = TRUE,
    full.names = TRUE
  )
}

#' Parse a single file and return a data.frame with one row per call
#' to a known download function. Returns NULL when the file does not
#' parse or contains no hit.
#' @noRd
.scan_one_file_for_downloads <- function(path) {
  src <- tryCatch(
    .read_r_source(path),
    error = function(e) {
      cli::cli_warn(c(
        "x" = "audit_downloads(): could not read {.path {path}}: {conditionMessage(e)}."
      ))
      NULL
    }
  )
  if (is.null(src) || !nzchar(src)) {
    return(NULL)
  }
  parsed <- tryCatch(
    parse(text = src, keep.source = TRUE),
    error = function(e) {
      cli::cli_warn(c(
        "x" = "audit_downloads(): could not parse {.path {path}}: {conditionMessage(e)}."
      ))
      NULL
    }
  )
  if (is.null(parsed)) {
    return(NULL)
  }
  pd <- utils::getParseData(parsed)
  if (is.null(pd) || nrow(pd) == 0L) {
    return(NULL)
  }

  hits <- .find_download_calls(pd)
  if (nrow(hits) == 0L) {
    return(NULL)
  }
  data.frame(
    file = rep(path, nrow(hits)),
    line = hits$line,
    `function` = hits$qualified,
    suggestion = "wrap in tryCatch() / skip_if_offline() in tests, or move to \\dontrun{} if the call is example-only",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

#' Walk a `getParseData()` table and return a data.frame of every
#' call site whose head matches a known download function.
#'
#' Two shapes are matched:
#' - `SYMBOL_FUNCTION_CALL` whose text is the bare name (e.g.
#'   `download.file`).
#' - `SYMBOL_PACKAGE NS_GET SYMBOL_FUNCTION_CALL` whose joined text
#'   is the qualified name (e.g. `utils::download.file`).
#'
#' A `SYMBOL_FUNCTION_CALL` token only appears at a call site, so
#' `download.file <- function(...)` (the assignment LHS) is a bare
#' `SYMBOL` and is not matched. That gives the caller a free guard
#' against shadowing-definitions false positives.
#' @noRd
.find_download_calls <- function(pd) {
  empty <- data.frame(
    line = integer(0),
    qualified = character(0),
    stringsAsFactors = FALSE
  )
  is_call <- pd$token == "SYMBOL_FUNCTION_CALL"
  if (!any(is_call)) {
    return(empty)
  }

  records <- list()
  for (i in which(is_call)) {
    fn <- pd$text[i]
    line <- pd$line1[i]
    pkg <- .qualifying_pkg(pd, fn_row = i)
    qualified <- if (is.null(pkg)) {
      fn
    } else {
      paste0(pkg$pkg, pkg$op, fn)
    }
    if (!qualified %in% .known_download_functions) {
      next
    }
    records[[length(records) + 1L]] <- data.frame(
      line = as.integer(line),
      qualified = qualified,
      stringsAsFactors = FALSE
    )
  }
  if (length(records) == 0L) {
    return(empty)
  }
  do.call(rbind, records)
}

#' For a `SYMBOL_FUNCTION_CALL` row at index `fn_row`, return the
#' qualifying package and operator (`pkg::` or `pkg:::`) when the
#' two preceding non-whitespace tokens form a `SYMBOL_PACKAGE NS_GET`
#' pair, else NULL.
#' @noRd
.qualifying_pkg <- function(pd, fn_row) {
  if (fn_row < 3L) {
    return(NULL)
  }
  prev <- pd[fn_row - 1L, ]
  pprev <- pd[fn_row - 2L, ]
  if (!identical(as.character(prev$token), "NS_GET") &&
        !identical(as.character(prev$token), "NS_GET_INT")) {
    return(NULL)
  }
  if (!identical(as.character(pprev$token), "SYMBOL_PACKAGE")) {
    return(NULL)
  }
  list(pkg = pprev$text, op = prev$text)
}

#' Read a source file. For `.R` we read directly; for `.Rmd` / `.qmd`
#' / `.Rnw` we extract code chunks via `knitr::purl()` so the parser
#' only sees the R subset.
#' @noRd
.read_r_source <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("r")) {
    return(paste(readLines(path, warn = FALSE), collapse = "\n"))
  }
  if (ext %in% c("rmd", "qmd", "rnw")) {
    out <- tempfile(fileext = ".R")
    on.exit(unlink(out), add = TRUE)
    suppressMessages(suppressWarnings(
      knitr::purl(path, output = out, quiet = TRUE, documentation = 0L)
    ))
    if (!file.exists(out)) {
      return("")
    }
    return(paste(readLines(out, warn = FALSE), collapse = "\n"))
  }
  ""
}

