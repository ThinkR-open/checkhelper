# Coverage gaps surfaced by automated review of #96.
# These four axes were claimed by the docs but not exercised by the original
# 28-block suite:
#   * input syntax: R 4.0+ raw strings r"(...)" / r"[...]" / r"---(...)---"
#   * each layer: file-level trailing-newline preservation
#   * return shape: find_nonascii_files()$n_tokens populated, not NA_integer_
#   * each layer: asciify_file() on non-R files reports a meaningful n_tokens

# ---- input syntax: raw strings ---------------------------------------------

test_that("asciify_r_source rewrites a raw string r\"(...)\" with non-ASCII", {
  src <- 'x <- r"(café)"\n'
  out <- asciify_r_source(src)

  # Output must still parse as R.
  expect_silent(parse(text = out))
  # And evaluate to the same string the user wrote.
  expect_identical(eval(parse(text = out)), eval(parse(text = src)))
  # Non-ASCII char must have been escaped.
  expect_true(grepl("\\\\u00e9", out, fixed = FALSE))
})

test_that("asciify_r_source handles every raw-string delimiter variant", {
  cases <- list(
    'r"(café)"',
    "r'(café)'",
    'r"[café]"',
    'r"{café}"',
    'r"---(café)---"',
    'R"--[café]--"'
  )
  for (raw in cases) {
    src <- paste0("x <- ", raw, "\n")
    out <- asciify_r_source(src)
    expect_silent(parse(text = out))
    expect_identical(
      eval(parse(text = out)),
      eval(parse(text = src)),
      info = raw
    )
  }
})

# ---- each layer: file-level invariants -------------------------------------

test_that("asciify_file preserves a trailing newline after rewriting", {
  withr::with_tempdir({
    content <- 'x <- "café"\n'
    writeBin(charToRaw(enc2utf8(content)), "f.R")

    asciify_file("f.R")

    bytes <- readBin("f.R", what = "raw", n = 10000L)
    expect_equal(as.integer(bytes[length(bytes)]), 0x0aL)
  })
})

test_that("asciify_file does not add a trailing newline when the input had none", {
  withr::with_tempdir({
    content <- 'x <- "café"'  # no trailing newline
    writeBin(charToRaw(enc2utf8(content)), "f.R")

    asciify_file("f.R")

    bytes <- readBin("f.R", what = "raw", n = 10000L)
    expect_false(as.integer(bytes[length(bytes)]) == 0x0aL)
  })
})

test_that("asciify_file is byte-equivalent on a no-op pure-ASCII input", {
  withr::with_tempdir({
    content <- "x <- 1\ny <- 2\n"
    writeBin(charToRaw(content), "f.R")

    asciify_file("f.R")

    expect_identical(
      readBin("f.R", what = "raw", n = 10000L),
      charToRaw(content)
    )
  })
})

# ---- return shape: n_tokens populated --------------------------------------

test_that("find_nonascii_files reports a real n_tokens for parseable R files", {
  withr::with_tempdir({
    dir.create("R")
    writeLines(
      c('x <- "café"', 'y <- "été"'),
      "R/x.R",
      useBytes = FALSE
    )

    out <- find_nonascii_files(".", scope = "R")

    expect_true(nrow(out) > 0L)
    expect_true(all(!is.na(out$n_tokens)))
    expect_true(all(out$n_tokens > 0L))
  })
})

# ---- each layer: non-R files report a meaningful n_tokens ------------------

test_that("asciify_file reports a non-zero n_tokens for non-R files", {
  withr::with_tempdir({
    writeLines("Le café est chaud", "notes.txt", useBytes = FALSE)

    res <- asciify_file("notes.txt")

    expect_false(res$changed)
    expect_gt(res$n_tokens, 0L)
  })
})
