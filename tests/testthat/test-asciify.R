# Tests for asciify_pkg / asciify_r_source / asciify_file / find_nonascii_*

# ---- find_nonascii_tokens ---------------------------------------------------

test_that("find_nonascii_tokens spots non-ASCII string literals and comments", {
  src <- '# pure ascii\nx <- "d\u00e9j\u00e0"\n# c\u00e9l\u00e9bre\nx'
  pd <- find_nonascii_tokens(src)
  expect_true(any(pd$token == "STR_CONST"))
  expect_true(any(pd$token == "COMMENT"))
  expect_false(any(pd$is_identifier))
  # The pure-ASCII comment is not flagged.
  expect_false(any(grepl("pure ascii", pd$text)))
})

test_that("find_nonascii_tokens flags non-ASCII identifiers", {
  src <- "fa\u00e7on <- 1\nfa\u00e7on"
  pd <- find_nonascii_tokens(src)
  expect_true(any(pd$is_identifier))
  expect_true(all(pd$text[pd$is_identifier] == "fa\u00e7on"))
})

test_that("find_nonascii_tokens returns an empty pd on pure-ASCII input", {
  pd <- find_nonascii_tokens('x <- "hello"\n# pure ascii\nx + 1')
  expect_equal(nrow(pd), 0L)
})

test_that("find_nonascii_tokens errors on unparseable input", {
  expect_error(find_nonascii_tokens("x <- "), regexp = "could not parse")
})

test_that("find_nonascii_tokens extracts each token faithfully when many tokens share one source", {
  # Regression guard for the shared-`lines` extraction path: one call must
  # produce per-token texts that match the original source byte-for-byte,
  # including a multi-line STR_CONST that exercises head/middle/tail
  # reconstruction alongside single-line neighbours.
  e <- "\u00e9"
  src <- paste0(
    "# header ", e, "\n",
    "x <- \"caf", e, "\"\n",
    "y <- \"ligne", e, " 1\nmilieu\nligne", e, " 3\"\n",
    "# footer ", e, "\n"
  )
  pd <- find_nonascii_tokens(src)

  expect_equal(sum(pd$token == "COMMENT"), 2L)
  expect_equal(sum(pd$token == "STR_CONST"), 2L)
  # Every extracted text contains the original non-ASCII char (no truncation
  # placeholder slipped through).
  expect_true(all(grepl(e, pd$text, fixed = TRUE)))
  expect_false(any(grepl("chars quoted with", pd$text, fixed = TRUE)))
  # The multi-line literal was reassembled with its embedded newlines intact.
  ml <- pd$text[grepl("\n", pd$text, fixed = TRUE)]
  expect_length(ml, 1L)
  expect_match(
    ml,
    paste0("ligne", e, " 1\nmilieu\nligne", e, " 3"),
    fixed = TRUE
  )
})

# ---- asciify_r_source: string literals --------------------------------------

test_that("asciify_r_source escapes non-ASCII inside string literals (auto)", {
  src <- 'x <- "d\u00e9j\u00e0 vu"'
  out <- asciify_r_source(src)
  expect_true(stringi::stri_enc_isascii(out))
  # Semantic value of x is preserved when the rewritten source is re-evaluated.
  e_in  <- new.env(parent = baseenv()); eval(parse(text = src), envir = e_in)
  e_out <- new.env(parent = baseenv()); eval(parse(text = out), envir = e_out)
  expect_identical(e_in$x, e_out$x)
})

test_that("escape strategy turns `\u00e9` into the canonical `\\u00e9`", {
  out <- asciify_r_source('x <- "\u00e9"', strategy = "escape")
  expect_match(out, "\\\\u00e9", fixed = FALSE)
  expect_true(stringi::stri_enc_isascii(out))
})

test_that("non-ASCII inside string literals stays the same string when re-evaluated", {
  src <- 'x <- "caf\u00e9"'
  out <- asciify_r_source(src)
  e <- new.env(parent = baseenv())
  eval(parse(text = out), envir = e)
  expect_identical(e$x, "caf\u00e9")
})

# ---- asciify_r_source: comments --------------------------------------------

test_that("asciify_r_source transliterates non-ASCII inside comments (auto)", {
  src <- '# accents \u00e9t\u00e9\nx <- 1'
  out <- asciify_r_source(src)
  expect_true(stringi::stri_enc_isascii(out))
  expect_match(out, "ete", fixed = TRUE)
  # the non-comment line is untouched
  expect_match(out, "x <- 1", fixed = TRUE)
})

test_that("asciify_r_source transliterates roxygen comments (#') the same way", {
  src <- "#' Description: caf\u00e9\n#' @return rien\nf <- function() NULL"
  out <- asciify_r_source(src)
  expect_true(stringi::stri_enc_isascii(out))
  expect_match(out, "Description: cafe", fixed = TRUE)
})

# ---- asciify_r_source: mixed contexts ---------------------------------------

test_that("asciify_r_source applies the per-token policy in mixed contexts", {
  src <- '# header \u00e9\nx <- "d\u00e9j\u00e0"\n# trailer'
  out <- asciify_r_source(src)
  expect_true(stringi::stri_enc_isascii(out))
  # comment was transliterated
  expect_match(out, "# header e", fixed = TRUE)
  # string literal was escaped (literal e followed by 'j' followed by a)
  expect_match(out, "\\u00e9j\\u00e0", fixed = TRUE)
})

test_that("asciify_r_source preserves a trailing newline", {
  src <- 'x <- "\u00e9"\n'
  out <- asciify_r_source(src)
  expect_true(endsWith(out, "\n"))
})

test_that("asciify_r_source returns the input unchanged when nothing to do", {
  src <- 'x <- "hello"\n# pure ascii\nx + 1'
  expect_identical(asciify_r_source(src), src)
})

# ---- identifier policy ------------------------------------------------------

test_that("asciify_r_source errors by default on a non-ASCII identifier", {
  src <- "fa\u00e7on <- 1"
  expect_error(asciify_r_source(src), regexp = "Non-ASCII identifier")
})

test_that("asciify_r_source(identifiers='warn') warns and leaves the id alone", {
  src <- "fa\u00e7on <- 1"
  expect_warning(out <- asciify_r_source(src, identifiers = "warn"))
  # the identifier stayed (still non-ASCII), but no other token was rewritten
  expect_match(out, "fa\u00e7on", fixed = TRUE)
})

test_that("asciify_r_source(identifiers='skip') stays silent and unchanged", {
  src <- "fa\u00e7on <- 1"
  out <- asciify_r_source(src, identifiers = "skip")
  expect_identical(out, src)
})

test_that("asciify_r_source rewrites strings even in a file with a non-ASCII id (warn)", {
  src <- "fa\u00e7on <- \"caf\u00e9\""
  out <- expect_warning(asciify_r_source(src, identifiers = "warn"))
  # the string was escaped
  expect_match(out, "\\\\u00e9", fixed = FALSE)
  # the identifier stays
  expect_match(out, "fa\u00e7on", fixed = TRUE)
})

# ---- strategy = "report" ----------------------------------------------------

test_that("asciify_r_source(strategy='report') is a pure read", {
  src <- '# accent \u00e9\nx <- "\u00e9"'
  expect_identical(asciify_r_source(src, strategy = "report"), src)
})

# ---- multi-line string ------------------------------------------------------

test_that("asciify_r_source handles a multi-line string literal", {
  src <- 'x <- "ligne\u00e9 1\nligne\u00e0 2"'
  out <- asciify_r_source(src)
  expect_true(stringi::stri_enc_isascii(out))
  # round-trip: the two strings hold the same characters
  v_in  <- eval(parse(text = src))
  v_out <- eval(parse(text = out))
  expect_identical(v_in, v_out)
})

# ---- asciify_file -----------------------------------------------------------

test_that("asciify_file rewrites a .R file in place", {
  tmp <- tempfile(fileext = ".R")
  writeLines('x <- "d\u00e9j\u00e0"', tmp, useBytes = FALSE)
  on.exit(unlink(tmp), add = TRUE)
  res <- asciify_file(tmp)
  expect_true(res$changed)
  txt <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(stringi::stri_enc_isascii(txt))
})

test_that("asciify_file with dry_run=TRUE leaves the file untouched", {
  tmp <- tempfile(fileext = ".R")
  src <- 'x <- "d\u00e9j\u00e0"'
  writeLines(src, tmp, useBytes = FALSE)
  on.exit(unlink(tmp), add = TRUE)
  before <- readLines(tmp, warn = FALSE)
  res <- asciify_file(tmp, dry_run = TRUE)
  after <- readLines(tmp, warn = FALSE)
  expect_identical(before, after)
  expect_true(res$changed)  # would have changed
})

test_that("asciify_file is a no-op on a pure-ASCII file", {
  tmp <- tempfile(fileext = ".R")
  writeLines('x <- "hello"', tmp)
  on.exit(unlink(tmp), add = TRUE)
  m_before <- file.info(tmp)$mtime
  Sys.sleep(0.01)
  res <- asciify_file(tmp)
  m_after <- file.info(tmp)$mtime
  expect_false(res$changed)
  expect_equal(m_before, m_after)
})

# ---- asciify_file: Rmd ------------------------------------------------------

test_that("asciify_file rewrites only the R chunks of an Rmd, leaving prose alone", {
  tmp <- tempfile(fileext = ".Rmd")
  writeLines(
    c(
      "# Titre avec accent: \u00e9t\u00e9",
      "",
      "Ceci est un **paragraphe** avec un caf\u00e9.",
      "",
      "```{r}",
      "x <- \"d\u00e9j\u00e0\"",
      "```",
      ""
    ),
    tmp, useBytes = FALSE
  )
  on.exit(unlink(tmp), add = TRUE)
  asciify_file(tmp)
  txt <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  # prose untouched: still contains the accented forms "\u00e9t\u00e9" / "caf\u00e9"
  expect_true(grepl("\u00e9t\u00e9", txt, fixed = TRUE))
  expect_true(grepl("caf\u00e9", txt, fixed = TRUE))
  # but the chunk is asciified
  expect_false(grepl("d\u00e9j\u00e0", txt, fixed = TRUE))
  expect_true(grepl("\\\\u00e9", txt, fixed = FALSE))
})

# ---- asciify_pkg ------------------------------------------------------------

test_that("asciify_pkg(dry_run = TRUE) reports without writing", {
  pkg_path <- tempfile(pattern = "asciify-pkg-")
  dir.create(pkg_path)
  on.exit(unlink(pkg_path, recursive = TRUE), add = TRUE)
  dir.create(file.path(pkg_path, "R"))
  writeLines(
    'x <- "d\u00e9j\u00e0"\n# comment \u00e9',
    file.path(pkg_path, "R", "f.R"),
    useBytes = FALSE
  )
  before <- readLines(file.path(pkg_path, "R", "f.R"))
  res <- asciify_pkg(pkg_path)
  after <- readLines(file.path(pkg_path, "R", "f.R"))
  expect_identical(before, after)
  expect_true(any(res$changed))
})

test_that("asciify_pkg(dry_run = FALSE) actually rewrites every R file in scope", {
  pkg_path <- tempfile(pattern = "asciify-pkg-")
  dir.create(pkg_path)
  on.exit(unlink(pkg_path, recursive = TRUE), add = TRUE)
  for (sub in c("R", "tests/testthat", "vignettes")) {
    dir.create(file.path(pkg_path, sub), recursive = TRUE)
  }
  writeLines('x <- "d\u00e9j\u00e0"',
             file.path(pkg_path, "R", "f.R"), useBytes = FALSE)
  writeLines('expect_equal("\u00e9t\u00e9", "\u00e9t\u00e9")',
             file.path(pkg_path, "tests/testthat", "test-x.R"), useBytes = FALSE)
  writeLines(
    c("```{r}", 'x <- "caf\u00e9"', "```"),
    file.path(pkg_path, "vignettes", "v.Rmd"), useBytes = FALSE
  )

  res <- asciify_pkg(pkg_path, dry_run = FALSE)

  # Every R/Rmd in scope was changed.
  expect_setequal(
    basename(res$path[res$changed]),
    c("f.R", "test-x.R", "v.Rmd")
  )
  for (f in res$path[res$changed]) {
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    if (tools::file_ext(f) == "R") {
      expect_true(stringi::stri_enc_isascii(txt), info = f)
    }
  }
})

test_that("asciify_pkg leaves a pure-ASCII file alone", {
  pkg_path <- tempfile(pattern = "asciify-pkg-")
  dir.create(pkg_path)
  on.exit(unlink(pkg_path, recursive = TRUE), add = TRUE)
  dir.create(file.path(pkg_path, "R"))
  writeLines("x <- 1", file.path(pkg_path, "R", "f.R"))
  res <- asciify_pkg(pkg_path, dry_run = FALSE)
  expect_false(any(res$changed))
})

# ---- find_nonascii_files ----------------------------------------------------

test_that("find_nonascii_files returns one row per offending line", {
  pkg_path <- tempfile(pattern = "asciify-pkg-")
  dir.create(pkg_path)
  on.exit(unlink(pkg_path, recursive = TRUE), add = TRUE)
  dir.create(file.path(pkg_path, "R"))
  writeLines(
    c('x <- "ok"', 'y <- "caf\u00e9"', "# pure", "# accent \u00e9"),
    file.path(pkg_path, "R", "f.R"), useBytes = FALSE
  )
  out <- find_nonascii_files(pkg_path)
  expect_equal(nrow(out), 2L)
  expect_setequal(out$line, c(2L, 4L))
})

test_that("find_nonascii_files returns an empty frame when there is nothing to flag", {
  pkg_path <- tempfile(pattern = "asciify-pkg-")
  dir.create(pkg_path)
  on.exit(unlink(pkg_path, recursive = TRUE), add = TRUE)
  dir.create(file.path(pkg_path, "R"))
  writeLines("x <- 1", file.path(pkg_path, "R", "f.R"))
  out <- find_nonascii_files(pkg_path)
  expect_equal(nrow(out), 0L)
  expect_named(out, c("file", "line", "text", "n_tokens"))
})

# ---- CRAN check sanity: rewritten code parses back identically ------------

test_that("CRAN sanity \u2014 every rewritten R source still parses and evaluates the same", {
  src <- c(
    "# r\u00e9sultat",
    "f <- function(x = \"d\u00e9faut\") {",
    "  paste0(x, \" cas\u00e9\")",
    "}",
    "f()"
  )
  src_text <- paste(src, collapse = "\n")
  out_text <- asciify_r_source(src_text)
  expect_true(stringi::stri_enc_isascii(out_text))
  # Both yield the same string when called.
  expect_identical(
    eval(parse(text = src_text)),
    eval(parse(text = out_text))
  )
})
