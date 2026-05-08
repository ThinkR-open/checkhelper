# Regression tests for audit_downloads() (#27).
#
# CRAN policy: package code that downloads files / hits the network at
# install or runtime must degrade gracefully when the network is
# unavailable (offline build farms, sandboxed CI, locked-down user
# environment). In particular, downloads from inside `.onLoad()`,
# `.onAttach()`, vignettes or examples are commonly cited reasons for
# CRAN rejection.
#
# audit_downloads() walks `R/`, `tests/`, `vignettes/` (and `inst/`)
# and surfaces every call to a known download / network function so
# the dev can review each one and decide whether to wrap it in a
# tryCatch / skip on offline / move to \dontrun{}. Detection is
# purely static: parse the AST, never source.

local_pkg_with_r <- function(files, envir = parent.frame()) {
  path <- tempfile("pkg-downloads-")
  dir.create(file.path(path, "R"), recursive = TRUE)
  for (name in names(files)) {
    target <- file.path(path, name)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    writeLines(files[[name]], target)
  }
  withr::defer(unlink(path, recursive = TRUE), envir = envir)
  path
}

test_that("audit_downloads() flags utils::download.file()", {
  pkg <- local_pkg_with_r(list(
    "R/foo.R" = c(
      "fetch <- function(url, dest) {",
      "  utils::download.file(url, destfile = dest)",
      "}"
    )
  ))

  out <- suppressMessages(audit_downloads(pkg))

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("file", "line", "function", "suggestion"))
  expect_equal(nrow(out), 1L)
  expect_equal(out[["function"]], "utils::download.file")
  expect_match(out$file, "foo\\.R$")
})

test_that("audit_downloads() flags bare download.file() (without utils::) too", {
  pkg <- local_pkg_with_r(list(
    "R/bar.R" = c(
      "fetch <- function(url, dest) {",
      "  download.file(url, destfile = dest)",
      "}"
    )
  ))

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 1L)
  expect_equal(out[["function"]], "download.file")
})

test_that("audit_downloads() flags httr::GET, curl::curl_download, etc.", {
  pkg <- local_pkg_with_r(list(
    "R/net.R" = c(
      "a <- function() httr::GET('https://x')",
      "b <- function() curl::curl_download('https://x', 'p')",
      "c <- function() curl::curl_fetch_memory('https://x')"
    )
  ))

  out <- suppressMessages(audit_downloads(pkg))

  expect_setequal(
    out[["function"]],
    c("httr::GET", "curl::curl_download", "curl::curl_fetch_memory")
  )
})

test_that("audit_downloads() reports correct line numbers", {
  pkg <- local_pkg_with_r(list(
    "R/lines.R" = c(
      "# 1 comment",                              # 1
      "f <- function() {",                        # 2
      "  utils::download.file('a', 'b')",         # 3
      "  invisible()",                            # 4
      "}",                                        # 5
      "g <- function() httr::GET('https://x')"    # 6
    )
  ))

  out <- suppressMessages(audit_downloads(pkg))

  expect_setequal(out$line, c(3L, 6L))
})

test_that("audit_downloads() walks tests/ and vignettes/ as well as R/", {
  pkg <- local_pkg_with_r(list(
    "R/r.R" = "a <- function() download.file('x', 'y')",
    "tests/testthat/test-it.R" = "b <- function() httr::GET('z')",
    "vignettes/x.Rmd" = c(
      "---",
      "title: x",
      "---",
      "",
      "```{r}",
      "curl::curl_download('a', 'b')",
      "```"
    )
  ))

  out <- suppressMessages(audit_downloads(pkg))

  expect_setequal(
    basename(out$file),
    c("r.R", "test-it.R", "x.Rmd")
  )
  expect_setequal(
    out[["function"]],
    c("download.file", "httr::GET", "curl::curl_download")
  )
})

test_that("audit_downloads() returns empty tibble when no download function is used", {
  pkg <- local_pkg_with_r(list(
    "R/clean.R" = c(
      "f <- function(x) x + 1",
      "g <- function(x) sum(x)"
    )
  ))

  out <- suppressMessages(audit_downloads(pkg))

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("file", "line", "function", "suggestion"))
  expect_equal(nrow(out), 0L)
})

test_that("audit_downloads() handles a missing R/ directory gracefully", {
  pkg <- tempfile("pkg-no-r-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  expect_message(out <- audit_downloads(pkg), regexp = "audit_downloads")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
})

test_that("audit_downloads() suggestion mentions a CRAN-safe pattern", {
  pkg <- local_pkg_with_r(list(
    "R/foo.R" = "f <- function() download.file('x', 'y')"
  ))

  out <- suppressMessages(audit_downloads(pkg))
  expect_match(
    out$suggestion,
    "tryCatch|\\\\dontrun|skip_if_offline|skip on CRAN",
    perl = TRUE
  )
})

test_that("audit_downloads() ignores function definitions whose name happens to match", {
  # A user-defined function called `download.file` (shadowing
  # utils::download.file) is unusual but legal. The auditor should
  # only flag *calls*, not the definition site, otherwise it would
  # produce a false positive on every package that wraps the
  # downloader.
  pkg <- local_pkg_with_r(list(
    "R/wrap.R" = c(
      "download.file <- function(url, dest) {",
      "  utils::download.file(url, destfile = dest)",
      "}"
    )
  ))

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 1L)
  expect_equal(out[["function"]], "utils::download.file")
})

test_that("audit_downloads() emits a cli summary message", {
  pkg <- local_pkg_with_r(list(
    "R/net.R" = "a <- function() httr::GET('https://x')"
  ))

  expect_message(audit_downloads(pkg), regexp = "audit_downloads.*download")
})

test_that("audit_downloads() flags pkg::: (triple colon) variants", {
  pkg <- local_pkg_with_r(list(
    "R/foo.R" = "f <- function() utils:::download.file('x', 'y')"
  ))

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 1L)
  expect_equal(out[["function"]], "utils:::download.file")
})

test_that("audit_downloads() scans uppercase extension variants", {
  pkg <- local_pkg_with_r(list(
    "vignettes/foo.QMD" = c(
      "```{r}",
      "utils::download.file('x', 'y')",
      "```"
    )
  ))

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 1L)
  expect_equal(out[["function"]], "utils::download.file")
})
