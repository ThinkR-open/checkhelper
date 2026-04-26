# Coverage gaps surfaced by automated review of #96.
# Axes covered here, beyond the original 28-block suite:
#   * input syntax: R 4.0+ raw strings r"(...)" / r"[...]" / r"---(...)---"
#   * each layer: file-level trailing-newline preservation
#   * return shape: find_nonascii_files()$n_tokens populated, not NA_integer_
#   * each layer: asciify_file() on non-R files reports a meaningful n_tokens
#   * each layer: asciify_file() on .Rmd reports a meaningful n_tokens
#   * return shape: find_nonascii_files() output sorted by file then line
#   * negative invariant: a NA file.size (broken symlink) doesn't crash scan
#   * return shape: asciify_pkg() return matches its "invisibly" contract
#
# All non-ASCII content is built from \uXXXX escapes so this test source
# stays byte-for-byte ASCII -- coherent with the package's CRAN-NOTE-
# prevention goal (a test file that itself contained non-ASCII bytes
# would re-introduce the very NOTE the package is built to remove).

# Single source of truth for the non-ASCII char used throughout the file.
e <- "\u00e9"   # an "e" with an acute accent
e_t_e <- paste0(e, "t", e)  # "<e-acute>t<e-acute>"

# ---- input syntax: raw strings ---------------------------------------------

test_that("asciify_r_source rewrites a raw string r\"(...)\" with non-ASCII", {
  src <- paste0("x <- r\"(caf", e, ")\"\n")
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
    paste0('r"(caf', e, ')"'),
    paste0("r'(caf", e, ")'"),
    paste0('r"[caf', e, ']"'),
    paste0('r"{caf', e, '}"'),
    paste0('r"---(caf', e, ')---"'),
    paste0('R"--[caf', e, ']--"')
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
    content <- paste0("x <- \"caf", e, "\"\n")
    writeBin(charToRaw(enc2utf8(content)), "f.R")

    asciify_file("f.R")

    bytes <- readBin("f.R", what = "raw", n = 10000L)
    expect_equal(as.integer(bytes[length(bytes)]), 0x0aL)
  })
})

test_that("asciify_file does not add a trailing newline when the input had none", {
  withr::with_tempdir({
    content <- paste0("x <- \"caf", e, "\"")  # no trailing newline
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
      c(paste0("x <- \"caf", e, "\""), paste0("y <- \"", e_t_e, "\"")),
      "R/x.R",
      useBytes = FALSE
    )

    out <- find_nonascii_files(".", scope = "R")

    expect_true(nrow(out) > 0L)
    expect_true(all(!is.na(out$n_tokens)))
    expect_true(all(out$n_tokens > 0L))
  })
})

test_that("find_nonascii_files sorts its output by file then line", {
  withr::with_tempdir({
    dir.create("R")
    # Three files, intentionally created in non-alphabetical order
    # of insertion. Multiple non-ASCII lines per file in non-line-sorted
    # positions to guard the per-file ordering too.
    writeLines(c("x <- 1", paste0("z <- \"", e, "\""),
                 paste0("a <- \"", e, "\""), "y <- 2"),
               "R/c.R", useBytes = FALSE)
    writeLines(paste0("k <- \"", e, "\""), "R/a.R", useBytes = FALSE)
    writeLines(c("ok <- 1", paste0("p <- \"", e, "\"")),
               "R/b.R", useBytes = FALSE)

    out <- find_nonascii_files(".", scope = "R")

    expect_true(nrow(out) >= 3L)
    expect_identical(out$file, out$file[order(out$file)])
    for (f in unique(out$file)) {
      lines <- out$line[out$file == f]
      expect_identical(lines, sort(lines), info = f)
    }
  })
})

test_that("find_nonascii_files survives a NA file.size (e.g. broken symlink)", {
  skip_on_os("windows")  # symlinks need elevated perms on Windows
  withr::with_tempdir({
    dir.create("R")
    writeLines(paste0("x <- \"", e, "\""), "R/real.R", useBytes = FALSE)
    file.symlink("does-not-exist", "R/broken.R")
    expect_true(is.na(file.size("R/broken.R")))

    out <- expect_no_error(
      find_nonascii_files(".", scope = "R")
    )
    expect_true(any(grepl("real.R$", out$file)))
  })
})

# ---- each layer: non-R / Rmd files report a meaningful n_tokens -----------

test_that("asciify_file reports a non-zero n_tokens for non-R files", {
  withr::with_tempdir({
    writeLines(paste0("Le caf", e, " est chaud"), "notes.txt",
               useBytes = FALSE)

    res <- asciify_file("notes.txt")

    expect_false(res$changed)
    expect_gt(res$n_tokens, 0L)
  })
})

test_that("asciify_file reports a non-zero n_tokens for an Rmd with non-ASCII in chunks", {
  withr::with_tempdir({
    writeLines(c(
      "---",
      "title: demo",
      "---",
      "",
      "Some prose without accents.",
      "",
      "```{r}",
      paste0("x <- \"caf", e, "\""),
      "```",
      ""
    ), "doc.Rmd", useBytes = FALSE)

    res <- asciify_file("doc.Rmd", dry_run = TRUE)

    expect_gt(res$n_tokens, 0L)
  })
})

# ---- return shape: asciify_pkg returns invisibly ---------------------------

test_that("asciify_pkg() returns its summary invisibly", {
  pkg_path <- tempfile(pattern = "asciify-pkg-")
  dir.create(pkg_path)
  on.exit(unlink(pkg_path, recursive = TRUE), add = TRUE)
  writeLines(c("Package: dummy", "Version: 0.0.1"),
             file.path(pkg_path, "DESCRIPTION"))
  dir.create(file.path(pkg_path, "R"))
  writeLines(paste0("x <- \"caf", e, "\""),
             file.path(pkg_path, "R", "f.R"),
             useBytes = FALSE)

  visible <- withVisible(
    suppressMessages(asciify_pkg(pkg_path, dry_run = TRUE))
  )$visible
  expect_false(visible)
})
