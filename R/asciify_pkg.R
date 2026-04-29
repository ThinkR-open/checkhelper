#' Find non-ASCII tokens inside a piece of R source code
#'
#' Parses `text` with [base::parse()] and [utils::getParseData()] and returns
#' the token rows whose source text is not pure ASCII. Used as the building
#' block of [asciify_r_source()] and [asciify_pkg()].
#'
#' Compared to a hand-rolled regex (e.g. the one used by `dreamRs/prefixer`),
#' this catches every relevant context exactly once: string literals,
#' comments, identifiers, numeric literals, etc., without false matches on
#' lookalike characters that appear inside larger tokens.
#'
#' @param text character(1), R source code (one element, possibly with
#'   embedded newlines).
#'
#' @return a data.frame, the subset of `getParseData()` whose `text` field
#'   contains at least one non-ASCII byte. An extra logical column
#'   `is_identifier` flags symbol-like tokens that should not be auto-rewritten.
#'
#' @seealso [asciify_r_source()] to apply the rewrite,
#'   [find_nonascii_files()] to scan a whole directory.
#' @export
find_nonascii_tokens <- function(text) {
  stopifnot(is.character(text), length(text) == 1L)
  if (!nzchar(text)) return(empty_token_pd())

  parsed <- tryCatch(
    parse(text = text, keep.source = TRUE),
    error = function(e) {
      stop(
        "asciify could not parse the input as R code: ",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )

  pd <- utils::getParseData(parsed, includeText = TRUE)
  if (is.null(pd) || !nrow(pd)) return(empty_token_pd())

  pd <- pd[!is.na(pd$text) & nzchar(pd$text), , drop = FALSE]
  # `expr` rows wrap their children and would cause overlapping rewrites
  # (e.g. an expr containing both an identifier and a string literal). Keep
  # only terminal tokens - those are the source-faithful leaves.
  pd <- pd[isTRUE_each(pd$terminal), , drop = FALSE]

  # getParseData() truncates long STR_CONST text to a placeholder
  # ("[NNN chars quoted with 'x']") past an internal limit that
  # `keep.source.maxchars` does not actually control. Re-extract the
  # literal source for each terminal token from `text` so the ASCII check
  # sees the real bytes.
  # Split once: extract_token_source() runs per row and would otherwise
  # re-split on every call - O(n_lines * n_tokens) on big files.
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  pd$text <- vapply(
    seq_len(nrow(pd)),
    function(i) extract_token_source(lines, pd[i, ]),
    character(1L)
  )

  hits <- !stringi::stri_enc_isascii(pd$text)
  pd <- pd[hits, , drop = FALSE]
  if (!nrow(pd)) return(empty_token_pd())

  pd$is_identifier <- pd$token %in% c(
    "SYMBOL", "SYMBOL_FUNCTION_CALL",
    "SYMBOL_FORMALS", "SYMBOL_SUB",
    "SYMBOL_PACKAGE", "SLOT"
  )
  pd
}

#' @noRd
isTRUE_each <- function(x) {
  vapply(x, isTRUE, logical(1L))
}

#' Re-extract the literal source of a token from the original text.
#'
#' Workaround for getParseData()'s STR_CONST-text truncation: it falls back
#' to a "[NNN chars quoted with 'x']" placeholder for long literals,
#' regardless of `keep.source.maxchars`.
#'
#' @param lines source already split on `\n` (passed in once by
#'   [find_nonascii_tokens()] to avoid an O(n_tokens) re-split).
#' @noRd
extract_token_source <- function(lines, row) {
  if (row$line1 < 1L || row$line2 > length(lines)) return(row$text)
  if (row$line1 == row$line2) {
    return(stringi::stri_sub(lines[row$line1], row$col1, row$col2))
  }
  head <- stringi::stri_sub(lines[row$line1], row$col1, -1L)
  tail <- stringi::stri_sub(lines[row$line2], 1L, row$col2)
  middle <- if (row$line2 - row$line1 > 1L) {
    lines[seq.int(row$line1 + 1L, row$line2 - 1L)]
  } else {
    character()
  }
  paste(c(head, middle, tail), collapse = "\n")
}

#' @noRd
empty_token_pd <- function() {
  data.frame(
    line1 = integer(), col1 = integer(),
    line2 = integer(), col2 = integer(),
    id = integer(), parent = integer(),
    token = character(), terminal = logical(),
    text = character(), is_identifier = logical(),
    stringsAsFactors = FALSE
  )
}

#' Rewrite a single token's text according to a strategy
#'
#' @param text the token's source text (character(1)).
#' @param token the token type from [utils::getParseData()] (e.g. `STR_CONST`,
#'   `COMMENT`).
#' @param strategy one of `"auto"`, `"escape"`, `"translit"`, `"report"`.
#'   See [asciify_r_source()].
#'
#' @return character(1), the rewritten token (or the input unchanged for
#'   `"report"`).
#' @noRd
rewrite_nonascii_token <- function(text, token, strategy) {
  strategy <- match.arg(
    strategy,
    c("auto", "escape", "translit", "report")
  )
  if (strategy == "report") return(text)
  if (strategy == "auto") {
    strategy <- if (token == "STR_CONST") "escape" else "translit"
  }
  if (strategy == "escape") {
    if (token == "STR_CONST") {
      escape_str_const(text)
    } else {
      escape_chars_only(text)
    }
  } else {
    # translit: drop the diacritics, leave the rest alone (quote delimiters,
    # escape sequences, etc. round-trip cleanly through Latin-ASCII).
    stringi::stri_trans_general(text, "Latin-ASCII")
  }
}

#' Replace each non-ASCII code point by its `\\uXXXX` / `\\UXXXXXXXX` escape.
#'
#' Unlike [stringi::stri_escape_unicode()], this leaves backslashes,
#' quotes and newlines alone - so an R STR_CONST text like `"d\\nej\\\\a"`
#' round-trips correctly when only the diacritic needs escaping.
#'
#' @noRd
escape_chars_only <- function(text) {
  if (stringi::stri_enc_isascii(text)) return(text)
  chars <- strsplit(text, "", fixed = TRUE)[[1L]]
  bad <- !stringi::stri_enc_isascii(chars)
  if (!any(bad)) return(text)
  cps <- utf8ToInt(paste(chars[bad], collapse = ""))
  enc <- ifelse(
    cps <= 0xFFFFL,
    sprintf("\\u%04x", cps),
    sprintf("\\U%08x", cps)
  )
  chars[bad] <- enc
  paste(chars, collapse = "")
}

#' Escape the *content* of a STR_CONST token, preserving its quote
#' delimiters and any backslash-escapes the user wrote.
#'
#' @noRd
escape_str_const <- function(text) {
  # Standard quoted forms: "..." and '...'.
  first <- substr(text, 1L, 1L)
  if (first %in% c("\"", "'")) {
    last <- substr(text, nchar(text), nchar(text))
    if (identical(first, last)) {
      inner <- substr(text, 2L, nchar(text) - 1L)
      return(paste0(first, escape_chars_only(inner), last))
    }
  }
  # Raw strings: r"(...)", r"[...]", r"{...}", with optional dashes.
  # We can't just inject \uXXXX inside a raw literal: raw strings do NOT
  # interpret backslash escapes. Convert to a regular " "-quoted literal
  # whose *value* is identical, then escape the non-ASCII content as
  # usual. The (...) / [...] / {...} delimiter and dashes are dropped
  # because they only matter to the raw form.
  rx <- "^([rR])(\"|')([-]*)([\\(\\[\\{])(.*)([\\)\\]\\}])([-]*)\\2$"
  if (grepl(rx, text, perl = TRUE)) {
    m <- regmatches(text, regexec(rx, text, perl = TRUE))[[1L]]
    if (length(m) == 8L) {
      inner <- m[6L]
      # Escape what regular-string syntax would otherwise reinterpret.
      inner <- gsub("\\", "\\\\", inner, fixed = TRUE)
      inner <- gsub("\"", "\\\"", inner, fixed = TRUE)
      inner <- gsub("\n", "\\n", inner, fixed = TRUE)
      inner <- gsub("\t", "\\t", inner, fixed = TRUE)
      inner <- gsub("\r", "\\r", inner, fixed = TRUE)
      return(paste0("\"", escape_chars_only(inner), "\""))
    }
  }
  # Fallback: only escape what is non-ASCII.
  escape_chars_only(text)
}

#' Rewrite non-ASCII characters inside a string of R source code
#'
#' @param text character(1), the full source of an R script.
#' @param strategy one of:
#'   * `"auto"` (default): per-token policy - `\\uXXXX` escape inside
#'     string literals (so they remain semantically equivalent and CRAN-safe);
#'     `Latin-ASCII` transliteration (drops diacritics, e.g. an accented
#'     `e` becomes plain `e`) inside comments and roxygen blocks (where
#'     escapes would not be interpreted).
#'   * `"escape"`: force `\\uXXXX` escape on every non-identifier token.
#'   * `"translit"`: force ASCII transliteration on every non-identifier token.
#'   * `"report"`: rewrite nothing, just return the input unchanged. Useful
#'     in conjunction with [find_nonascii_tokens()] for a dry run.
#' @param identifiers what to do when a non-ASCII identifier (variable,
#'   function name, formal, slot...) is found:
#'   * `"error"` (default): stop. Renaming an identifier changes the API
#'     surface and is not safe to automate.
#'   * `"warn"`: warn and leave the token unchanged.
#'   * `"skip"`: silently leave the token unchanged.
#'
#' @return character(1), the rewritten source code. The original is returned
#'   unchanged if no non-ASCII tokens are found.
#'
#' @details
#' This function does **not** touch identifiers, even with
#' `identifiers = "skip"`: CRAN's policy is to forbid non-ASCII identifiers,
#' but rewriting them automatically is unsafe (it would silently rename the
#' user's exported API). Use [find_nonascii_tokens()] to surface them.
#'
#' Strings declared with the R 4.0 raw form (`r"(...)"`, `R"---(...)---"`)
#' are detected - by default they are still treated like regular `STR_CONST`
#' (escaped); pass `strategy = "translit"` if you want to keep them raw and
#' lose the accents instead.
#'
#' @examples
#' src <- '
#' # accent dans un commentaire: ete
#' x <- "deja vu"
#' '
#' cat(asciify_r_source(src))
#' @export
asciify_r_source <- function(text,
                             strategy = c("auto", "escape", "translit", "report"),
                             identifiers = c("error", "warn", "skip")) {
  stopifnot(is.character(text), length(text) == 1L)
  strategy <- match.arg(strategy)
  identifiers <- match.arg(identifiers)

  pd <- find_nonascii_tokens(text)
  if (!nrow(pd)) return(text)

  bad_ids <- pd[pd$is_identifier, , drop = FALSE]
  if (nrow(bad_ids)) {
    msg <- sprintf(
      "Non-ASCII identifier(s) found, refusing to auto-rewrite: %s",
      paste(unique(bad_ids$text), collapse = ", ")
    )
    switch(identifiers,
      error = stop(msg, call. = FALSE),
      warn  = warning(msg, call. = FALSE),
      skip  = invisible(NULL)
    )
  }

  pd <- pd[!pd$is_identifier, , drop = FALSE]
  if (!nrow(pd) || strategy == "report") return(text)

  # Process tokens from end to start so earlier byte/char offsets stay valid.
  pd <- pd[order(-pd$line1, -pd$col1), , drop = FALSE]

  # Split with a stable separator. We keep the trailing newline if any so
  # the round-trip preserves it.
  has_trailing_nl <- substr(text, nchar(text), nchar(text)) == "\n"
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  if (length(lines) == 0L) lines <- ""

  for (i in seq_len(nrow(pd))) {
    tok <- pd[i, ]
    new <- rewrite_nonascii_token(tok$text, tok$token, strategy)
    if (tok$line1 == tok$line2) {
      lines[tok$line1] <- char_splice(lines[tok$line1], tok$col1, tok$col2, new)
    } else {
      # Multi-line token (typically a multi-line STR_CONST). Replace by
      # rebuilding the slice - split the new value on \n so the line array
      # stays consistent.
      head <- char_left(lines[tok$line1], tok$col1 - 1L)
      tail <- char_right(lines[tok$line2], tok$col2 + 1L)
      new_lines <- strsplit(new, "\n", fixed = TRUE)[[1L]]
      if (length(new_lines) == 0L) new_lines <- ""
      new_lines[1L] <- paste0(head, new_lines[1L])
      new_lines[length(new_lines)] <- paste0(new_lines[length(new_lines)], tail)
      lines <- c(
        if (tok$line1 > 1L) lines[seq_len(tok$line1 - 1L)],
        new_lines,
        if (tok$line2 < length(lines)) lines[seq.int(tok$line2 + 1L, length(lines))]
      )
    }
  }

  out <- paste(lines, collapse = "\n")
  if (has_trailing_nl && substr(out, nchar(out), nchar(out)) != "\n") {
    out <- paste0(out, "\n")
  }
  out
}

#' @noRd
char_splice <- function(line, col1, col2, replacement) {
  paste0(
    char_left(line, col1 - 1L),
    replacement,
    char_right(line, col2 + 1L)
  )
}

#' @noRd
char_left <- function(line, n) {
  if (n <= 0L) "" else stringi::stri_sub(line, 1L, n)
}

#' @noRd
char_right <- function(line, from) {
  if (from > stringi::stri_length(line)) "" else stringi::stri_sub(line, from, -1L)
}

#' Apply the asciify rewrite to a single R / R-related file
#'
#' Writes the rewritten file in place (unless `dry_run = TRUE`). Files that
#' do not contain any non-ASCII characters are skipped without rewriting,
#' so file mtimes stay clean.
#'
#' @param path path to a file. Suffixes `.R`, `.r`, `.Rmd`, `.qmd` are
#'   handled as R source. `.Rnw` (Sweave) and any other suffix are
#'   scanned read-only — Sweave's `<<>>= ... @` chunk syntax is not
#'   handled by the rewriter.
#' @inheritParams asciify_r_source
#' @param dry_run logical. If `TRUE`, report what would change but do not
#'   write the file. Default `FALSE`.
#'
#' @return invisibly, a list with `path`, `changed` (logical), `n_tokens`
#'   (integer; for R/Rmd/qmd, the count of non-ASCII parser tokens; for
#'   any other file type — including `.Rnw` — the count of non-ASCII
#'   characters), and `text` (the rewritten content if `changed`, else
#'   the original).
#' @export
asciify_file <- function(path,
                         strategy = c("auto", "escape", "translit", "report"),
                         identifiers = c("error", "warn", "skip"),
                         dry_run = FALSE) {
  strategy <- match.arg(strategy)
  identifiers <- match.arg(identifiers)
  stopifnot(file.exists(path))

  raw <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (!length(raw)) {
    return(invisible(list(path = path, changed = FALSE, n_tokens = 0L, text = "")))
  }

  # readLines() drops the trailing-newline status; capture it from bytes so
  # we can re-apply it on write and not pollute diffs.
  trailing_nl <- has_trailing_newline(path)

  text <- paste(raw, collapse = "\n")
  ext <- tolower(tools::file_ext(path))
  if (!ext %in% c("r", "rmd", "qmd")) {
    return(invisible(list(
      path = path, changed = FALSE,
      n_tokens = count_nonascii_chars(text),
      text = text
    )))
  }

  if (ext == "r") {
    new <- asciify_r_source(text, strategy = strategy, identifiers = identifiers)
  } else {
    # In Rmd/qmd we only rewrite the R chunks - the prose belongs to the
    # author and is not subject to CRAN's R-code rule. Simpler and safer than
    # tampering with the markdown.
    new <- asciify_rmd(text, strategy = strategy, identifiers = identifiers)
  }

  changed <- !identical(new, text)
  if (changed && !isTRUE(dry_run)) {
    write_text_preserving_eol(new, path, trailing_nl = trailing_nl)
  }
  # For .Rmd/.qmd, parsing the whole document as R fails (the prose
  # is not R), so the safe wrapper would return 0 tokens. Sum tokens
  # across the same chunks asciify_rmd() rewrites.
  n_tokens <- if (ext == "r") {
    nrow(find_nonascii_tokens_safe(text))
  } else {
    sum_chunk_nonascii_tokens(text)
  }
  invisible(list(
    path = path,
    changed = changed,
    n_tokens = n_tokens,
    text = new
  ))
}

#' @noRd
sum_chunk_nonascii_tokens <- function(text) {
  rx <- "(?ms)^([ \\t]*```\\{r[^\\n]*\\n)(.*?)(\\n[ \\t]*```\\s*$)"
  m <- regmatches(text, gregexpr(rx, text, perl = TRUE))[[1L]]
  if (!length(m)) return(0L)
  bodies <- vapply(m, function(chunk) {
    parts <- regmatches(chunk, regexec(rx, chunk, perl = TRUE))[[1L]]
    if (length(parts) >= 4L) parts[3L] else ""
  }, character(1L))
  sum(vapply(bodies, function(b) nrow(find_nonascii_tokens_safe(b)),
             integer(1L)))
}

#' @noRd
has_trailing_newline <- function(path) {
  size <- file.size(path)
  if (is.na(size) || size == 0L) return(FALSE)
  con <- file(path, "rb")
  on.exit(close(con))
  seek(con, where = size - 1L, origin = "start")
  last <- readBin(con, what = "raw", n = 1L)
  length(last) == 1L && last == as.raw(0x0a)
}

#' @noRd
write_text_preserving_eol <- function(text, path, trailing_nl) {
  bytes <- charToRaw(enc2utf8(text))
  if (isTRUE(trailing_nl) &&
      (!length(bytes) || bytes[length(bytes)] != as.raw(0x0a))) {
    bytes <- c(bytes, as.raw(0x0a))
  }
  if (isFALSE(trailing_nl) &&
      length(bytes) && bytes[length(bytes)] == as.raw(0x0a)) {
    bytes <- bytes[-length(bytes)]
  }
  writeBin(bytes, con = path)
}

#' @noRd
count_nonascii_chars <- function(text) {
  if (!length(text) || !nzchar(text)) return(0L)
  sum(!stringi::stri_enc_isascii(strsplit(text, "", fixed = TRUE)[[1L]]))
}

#' @noRd
find_nonascii_tokens_safe <- function(text) {
  tryCatch(find_nonascii_tokens(text), error = function(e) empty_token_pd())
}

#' Rewrite the R chunks of an Rmd/qmd file, leaving prose alone.
#' @noRd
asciify_rmd <- function(text, strategy, identifiers) {
  # Match ```{r ...} ... ``` chunks (knitr's standard form).
  rx <- "(?ms)^([ \\t]*```\\{r[^\\n]*\\n)(.*?)(\\n[ \\t]*```\\s*$)"
  m <- gregexpr(rx, text, perl = TRUE)[[1L]]
  if (length(m) == 1L && m == -1L) return(text)
  starts <- as.integer(m)
  lengths <- attr(m, "match.length")

  # Process from end to start.
  ord <- order(-starts)
  for (i in ord) {
    chunk <- substr(text, starts[i], starts[i] + lengths[i] - 1L)
    parts <- regmatches(chunk, regexec(rx, chunk, perl = TRUE))[[1L]]
    if (length(parts) < 4L) next
    head <- parts[2L]; body <- parts[3L]; tail <- parts[4L]
    new_body <- tryCatch(
      asciify_r_source(body, strategy = strategy, identifiers = identifiers),
      error = function(e) body  # leave malformed chunks alone
    )
    new_chunk <- paste0(head, new_body, tail)
    text <- paste0(
      substr(text, 1L, starts[i] - 1L),
      new_chunk,
      substr(text, starts[i] + lengths[i], nchar(text))
    )
  }
  text
}

#' Scan a directory tree for files containing non-ASCII characters
#'
#' Lightweight cousin of `dreamRs/prefixer::show_nonascii_file()` - returns a
#' tidy data.frame instead of pushing markers to the RStudio editor.
#'
#' @param path directory to scan, recursively.
#' @param scope subdirectories, relative to `path`, to consider. Defaults to
#'   the CRAN-relevant ones (`R`, `tests`, `vignettes`, `man`, plus the
#'   top-level `DESCRIPTION` / `NAMESPACE`).
#' @param ignore_ext file extensions (lowercase, no dot) that are treated as
#'   binary and skipped without reading.
#' @param size_limit only files smaller than this many bytes are scanned;
#'   safety net for accidentally bundled large blobs.
#'
#' @return a data.frame with columns `file`, `line`, `text`, `n_tokens`
#'   (count of non-ASCII characters on the offending line; well-defined
#'   for both R and non-R files), sorted by file then line. Empty if
#'   nothing is found.
#' @export
find_nonascii_files <- function(path = ".",
                                scope = c("R", "tests", "vignettes", "man",
                                          "DESCRIPTION", "NAMESPACE"),
                                ignore_ext = c("png", "jpg", "jpeg", "gif",
                                                 "rds", "rda", "rdata",
                                                 "pdf", "ico", "svg"),
                                size_limit = 5e5) {
  path <- normalizePath(path, mustWork = TRUE)
  files <- collect_pkg_files(path, scope = scope, ignore_ext = ignore_ext)

  out <- lapply(files, function(f) {
    # file.size() returns NA for unreadable entries (e.g. broken symlinks);
    # skip silently rather than letting the >= comparison error out the scan.
    sz <- file.size(f)
    if (is.na(sz) || sz >= size_limit) return(NULL)
    raw <- tryCatch(
      readLines(f, warn = FALSE, encoding = "UTF-8"),
      error = function(e) NULL
    )
    if (is.null(raw) || !length(raw)) return(NULL)
    bad <- which(!stringi::stri_enc_isascii(raw))
    if (!length(bad)) return(NULL)
    data.frame(
      file = f,
      line = bad,
      text = raw[bad],
      n_tokens = vapply(raw[bad], count_nonascii_chars, integer(1L)),
      stringsAsFactors = FALSE
    )
  })
  out <- out[!vapply(out, is.null, logical(1L))]
  if (!length(out)) {
    return(data.frame(
      file = character(), line = integer(),
      text = character(), n_tokens = integer(),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, out)
  out[order(out$file, out$line), , drop = FALSE]
}

#' @noRd
collect_pkg_files <- function(path, scope, ignore_ext) {
  out <- character()
  for (s in scope) {
    p <- file.path(path, s)
    if (!file.exists(p)) next
    if (file.info(p)$isdir) {
      out <- c(out, list.files(p, recursive = TRUE, full.names = TRUE,
                               include.dirs = FALSE, no.. = TRUE))
    } else {
      out <- c(out, p)
    }
  }
  ext <- tolower(tools::file_ext(out))
  out[!ext %in% tolower(ignore_ext)]
}

#' Asciify every CRAN-relevant file of an R package
#'
#' Walks the package tree, applies [asciify_file()] to each `R` /
#' `tests` / `vignettes` source, and reports a summary.
#'
#' Defaults to `dry_run = TRUE` because rewriting a whole package in place
#' is invasive - call once with the default to inspect the diff, then re-run
#' with `dry_run = FALSE` to commit. Use [find_nonascii_files()] for a
#' read-only scan that does not even attempt to parse non-`.R` files.
#'
#' @inheritParams find_nonascii_files
#' @inheritParams asciify_r_source
#' @param scope subdirectories to rewrite. Defaults to `c("R", "tests",
#'   "vignettes")` - the directories where CRAN raises
#'   `non-ASCII characters in code`. `man/` is intentionally excluded
#'   because Rd files are usually generated by roxygen2 from the R sources;
#'   rewriting the source files is enough.
#' @param dry_run logical, default `TRUE` for safety. Pass `FALSE` to write.
#'
#' @return invisibly, a data.frame with one row per inspected file:
#'   `path`, `changed` (logical), `n_tokens`. The full rewritten content is
#'   not returned to keep the result printable.
#' @export
#'
#' @examples
#' \dontrun{
#' # Read-only scan
#' nonascii <- find_nonascii_files(".")
#' nonascii
#'
#' # Dry run: preview the rewrite
#' summary <- asciify_pkg(".")
#' summary
#'
#' # Apply for real
#' asciify_pkg(".", dry_run = FALSE)
#' }
asciify_pkg <- function(path = ".",
                        scope = c("R", "tests", "vignettes"),
                        strategy = c("auto", "escape", "translit", "report"),
                        identifiers = c("error", "warn", "skip"),
                        dry_run = TRUE) {
  strategy <- match.arg(strategy)
  identifiers <- match.arg(identifiers)
  path <- normalizePath(path, mustWork = TRUE)

  files <- collect_pkg_files(
    path = path,
    scope = scope,
    ignore_ext = c("png", "jpg", "jpeg", "gif", "rds", "rda", "rdata",
                   "pdf", "ico", "svg")
  )
  files <- files[tolower(tools::file_ext(files)) %in% c("r", "rmd", "qmd")]

  rows <- lapply(files, function(f) {
    res <- tryCatch(
      asciify_file(
        path = f,
        strategy = strategy,
        identifiers = identifiers,
        dry_run = dry_run
      ),
      error = function(e) {
        warning(sprintf("asciify_pkg: skipping %s \u2014 %s", f, conditionMessage(e)),
                call. = FALSE)
        list(path = f, changed = FALSE, n_tokens = NA_integer_)
      }
    )
    data.frame(
      path = res$path,
      changed = res$changed,
      n_tokens = res$n_tokens %||% 0L,
      stringsAsFactors = FALSE
    )
  })
  out <- if (length(rows)) do.call(rbind, rows) else data.frame(
    path = character(), changed = logical(),
    n_tokens = integer(), stringsAsFactors = FALSE
  )
  invisible(out)
}

# tiny null-coalescer to avoid an extra dep just for it
`%||%` <- function(a, b) if (is.null(a)) b else a
