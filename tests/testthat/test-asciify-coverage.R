# Coverage-targeted tests for tiny branches inside asciify_helpers.R.
# Each block targets one or two specific zero-coverage lines.

test_that("`%||%` returns the right side when the left is NULL", {
  expect_equal(checkhelper:::`%||%`(NULL, "fallback"), "fallback")
})

test_that("`%||%` returns the left side when the left is not NULL", {
  expect_equal(checkhelper:::`%||%`("present", "fallback"), "present")
})

test_that("find_nonascii_tokens() returns empty on empty text", {
  res <- checkhelper:::find_nonascii_tokens("")
  expect_equal(nrow(res), 0L)
})

test_that("find_nonascii_tokens() returns empty when parse data is empty", {
  # A whitespace-only file parses to zero expressions, so getParseData
  # returns an empty table.
  res <- checkhelper:::find_nonascii_tokens("   \n\t \n")
  expect_equal(nrow(res), 0L)
})

test_that("rewrite_nonascii_token('report' strategy) returns the text unchanged", {
  expect_equal(
    checkhelper:::rewrite_nonascii_token(text = "\"déjà\"", token = "STR_CONST", strategy = "report"),
    "\"déjà\""
  )
})

test_that("escape_chars_only() short-circuits on pure-ASCII input", {
  expect_equal(checkhelper:::escape_chars_only("plain ascii only"), "plain ascii only")
})

test_that("escape_chars_only() handles a single-character non-ASCII string", {
  res <- checkhelper:::escape_chars_only("é")
  expect_match(res, "\\\\u")
})

test_that("escape_str_const() falls back to escape_chars_only on non-quoted text", {
  # A bare identifier (no surrounding quotes, not a raw literal) takes the
  # final fallback path.
  res <- checkhelper:::escape_str_const("déjà")
  expect_match(res, "\\\\u")
  expect_false(grepl("^[\"']", res))
})

test_that("has_trailing_newline() returns FALSE on a missing or empty file", {
  empty <- tempfile()
  file.create(empty)
  on.exit(unlink(empty), add = TRUE)
  expect_false(checkhelper:::has_trailing_newline(empty))

  missing_path <- tempfile()
  expect_false(checkhelper:::has_trailing_newline(missing_path))
})

test_that("has_trailing_newline() detects a file ending with a newline", {
  p <- tempfile()
  writeLines("hello", p)
  on.exit(unlink(p), add = TRUE)
  expect_true(checkhelper:::has_trailing_newline(p))
})

test_that("write_text_preserving_eol() strips a trailing newline when asked", {
  p <- tempfile()
  on.exit(unlink(p), add = TRUE)
  checkhelper:::write_text_preserving_eol(text = "hello\n", path = p, trailing_nl = FALSE)
  bytes <- readBin(p, what = "raw", n = file.size(p))
  expect_false(bytes[length(bytes)] == as.raw(0x0a))
})

test_that("write_text_preserving_eol() adds a trailing newline when asked", {
  p <- tempfile()
  on.exit(unlink(p), add = TRUE)
  checkhelper:::write_text_preserving_eol(text = "hello", path = p, trailing_nl = TRUE)
  bytes <- readBin(p, what = "raw", n = file.size(p))
  expect_true(bytes[length(bytes)] == as.raw(0x0a))
})

test_that("count_nonascii_chars() returns 0 on empty input", {
  expect_equal(checkhelper:::count_nonascii_chars(""), 0L)
  expect_equal(checkhelper:::count_nonascii_chars(character(0)), 0L)
})

test_that("count_nonascii_chars() counts non-ASCII characters", {
  expect_equal(checkhelper:::count_nonascii_chars("déjà"), 2L)
})

# --- More targeted helper coverage ------------------------------------------

test_that("asciify_file() returns an empty payload on an empty file", {
  empty <- tempfile(fileext = ".R")
  file.create(empty)
  on.exit(unlink(empty), add = TRUE)

  res <- checkhelper:::asciify_file(empty)
  expect_false(res$changed)
  expect_equal(res$n_tokens, 0L)
  expect_equal(res$n_chars, 0L)
})

test_that("asciify_file() leaves a non-R/Rmd/qmd file unchanged", {
  txt <- tempfile(fileext = ".txt")
  writeLines("plain text déjà", txt)
  on.exit(unlink(txt), add = TRUE)

  res <- checkhelper:::asciify_file(txt)
  expect_false(res$changed)
  # n_tokens equals n_chars for non-R files (no parsing happens).
  expect_equal(res$n_tokens, res$n_chars)
})

test_that("asciify_r_source() handles a multi-line STR_CONST containing non-ASCII", {
  # The multi-line STR_CONST branch (line ~287+ in asciify_r_source)
  # rebuilds the source by stitching the surrounding context around
  # the rewritten lines. Trigger it with a string literal that spans
  # two lines and contains a non-ASCII codepoint.
  src <- 'x <- "first line déjà\nsecond line"\n'

  out <- checkhelper:::asciify_r_source(
    src,
    strategy = "escape",
    identifiers = "skip"
  )

  expect_match(out, "\\\\u")
  expect_true(grepl("second line", out))
})

test_that(".asciify_pkg() returns an empty frame when the package has no scannable files", {
  pkg <- tempfile("pkg-no-files-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  out <- suppressMessages(checkhelper:::.asciify_pkg(path = pkg))
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0L)
})
