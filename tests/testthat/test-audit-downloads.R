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

test_that("audit_downloads() reports line numbers relative to the original Rmd source", {
  pkg <- local_pkg_with_r(list(
    "vignettes/v.Rmd" = c(
      "---",                                  # 1
      "title: v",                             # 2
      "---",                                  # 3
      "",                                     # 4
      "Some narrative.",                      # 5
      "",                                     # 6
      "```{r}",                               # 7
      "x <- 1",                               # 8
      "utils::download.file('a', 'b')",       # 9
      "```"                                   # 10
    )
  ))

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 1L)
  expect_equal(out$line, 9L)
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

# --- Import-aware detection of bare calls -----------------------------------

local_pkg_with_namespace <- function(r_files, namespace_lines, envir = parent.frame()) {
  path <- tempfile("pkg-ns-")
  dir.create(path)
  for (name in names(r_files)) {
    target <- file.path(path, name)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    writeLines(r_files[[name]], target)
  }
  writeLines(namespace_lines, file.path(path, "NAMESPACE"))
  withr::defer(unlink(path, recursive = TRUE), envir = envir)
  path
}

test_that("audit_downloads() flags bare GET() when NAMESPACE has importFrom(httr, GET)", {
  pkg <- local_pkg_with_namespace(
    r_files = list("R/net.R" = "f <- function() GET('https://x')"),
    namespace_lines = c("importFrom(httr, GET)")
  )

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 1L)
  expect_equal(out[["function"]], "httr::GET")
})

test_that("audit_downloads() flags bare GET() when NAMESPACE has import(httr)", {
  pkg <- local_pkg_with_namespace(
    r_files = list("R/net.R" = "f <- function() GET('https://x')"),
    namespace_lines = c("import(httr)")
  )

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 1L)
  expect_equal(out[["function"]], "httr::GET")
})

test_that("audit_downloads() does NOT flag bare GET(non-URL) when nothing is imported", {
  # No import AND no URL literal in the first arg: the auditor cannot
  # attribute the call to a watched namespace, so it stays quiet.
  pkg <- local_pkg_with_namespace(
    r_files = list("R/net.R" = "f <- function(key) GET(key)"),
    namespace_lines = c("export(f)")
  )

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 0L)
})

test_that("audit_downloads() does NOT flag bare GET() defined locally without import", {
  # The user-defined `GET()` shadow case. With no import, the auditor must
  # stay quiet. (Without the import-aware guard, the bare token would
  # produce false positives on every CRUD wrapper / cache helper called GET.)
  pkg <- local_pkg_with_namespace(
    r_files = list("R/cache.R" = c(
      "GET <- function(key) cache[[key]]",
      "g <- function() GET('hit')"
    )),
    namespace_lines = c("export(GET)")
  )

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 0L)
})

test_that("audit_downloads() flags importFrom only for the listed symbols (non-URL args)", {
  # `importFrom(httr, GET)` imports `GET` but NOT `POST`. With non-URL
  # arguments the auditor cannot fall back to the URL heuristic, so
  # POST must remain unflagged because the user has not imported it.
  pkg <- local_pkg_with_namespace(
    r_files = list("R/net.R" = c(
      "f <- function(req) GET(req)",
      "g <- function(req) POST(req)"
    )),
    namespace_lines = c("importFrom(httr, GET)")
  )

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 1L)
  expect_equal(out[["function"]], "httr::GET")
})

test_that("audit_downloads() still flags bare download.file() without an import (base R utils)", {
  # `download.file` lives in `utils`, which is attached by default in
  # every R session. No import is required to call it. The auditor must
  # keep flagging it regardless of NAMESPACE state.
  pkg <- local_pkg_with_namespace(
    r_files = list("R/dl.R" = "f <- function() download.file('x', 'y')"),
    namespace_lines = c("export(f)")
  )

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 1L)
  expect_equal(out[["function"]], "download.file")
})

# --- URL-literal heuristic (no-import bare call with https:// arg) ----------

test_that("audit_downloads() flags bare GET() with an https:// literal argument", {
  pkg <- local_pkg_with_namespace(
    r_files = list("R/net.R" = 'f <- function() GET("https://x.example/y")'),
    namespace_lines = c("export(f)")
  )

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 1L)
  expect_equal(out[["function"]], "httr::GET")
})

test_that("audit_downloads() flags bare POST() with an http:// literal argument", {
  pkg <- local_pkg_with_namespace(
    r_files = list("R/net.R" = "f <- function() POST('http://x.example')"),
    namespace_lines = c("export(f)")
  )

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 1L)
  expect_equal(out[["function"]], "httr::POST")
})

test_that("audit_downloads() flags bare curl_download() with an https:// literal argument", {
  pkg <- local_pkg_with_namespace(
    r_files = list("R/dl.R" = 'f <- function() curl_download("https://x.example/file", "/tmp/y")'),
    namespace_lines = c("export(f)")
  )

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 1L)
  expect_equal(out[["function"]], "curl::curl_download")
})

test_that("audit_downloads() does NOT flag bare GET() with a relative path argument", {
  pkg <- local_pkg_with_namespace(
    r_files = list("R/net.R" = 'f <- function() GET("/api/users")'),
    namespace_lines = c("export(f)")
  )

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 0L)
})

test_that("audit_downloads() does NOT flag bare GET() with a variable argument", {
  # The auditor cannot see the runtime value of `url`, so it must stay
  # quiet rather than guess. This is the case where the URL heuristic
  # gracefully degrades.
  pkg <- local_pkg_with_namespace(
    r_files = list("R/net.R" = c(
      "f <- function(url) GET(url)"
    )),
    namespace_lines = c("export(f)")
  )

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 0L)
})

test_that("audit_downloads() does NOT flag a local-helper call with a non-URL string", {
  pkg <- local_pkg_with_namespace(
    r_files = list("R/cache.R" = c(
      "GET <- function(key) cache[[key]]",
      "g <- function() GET('cache-hit')"
    )),
    namespace_lines = c("export(GET)")
  )

  out <- suppressMessages(audit_downloads(pkg))

  expect_equal(nrow(out), 0L)
})

# --- .first_arg_is_url() direct tests for branch coverage -------------------

test_that(".first_arg_is_url() detects http and https URL literals", {
  parse_pd <- function(src) {
    utils::getParseData(parse(text = src, keep.source = TRUE))
  }
  find_fn_row <- function(pd, name) {
    which(pd$token == "SYMBOL_FUNCTION_CALL" & pd$text == name)[1L]
  }

  pd <- parse_pd('GET("https://x")')
  expect_true(checkhelper:::.first_arg_is_url(pd, find_fn_row(pd, "GET")))

  pd <- parse_pd("GET('http://x')")
  expect_true(checkhelper:::.first_arg_is_url(pd, find_fn_row(pd, "GET")))

  pd <- parse_pd('GET("/api")')
  expect_false(checkhelper:::.first_arg_is_url(pd, find_fn_row(pd, "GET")))

  pd <- parse_pd("GET(url)")
  expect_false(checkhelper:::.first_arg_is_url(pd, find_fn_row(pd, "GET")))
})

test_that(".first_arg_is_url() returns FALSE on a no-arg call", {
  pd <- utils::getParseData(parse(text = "f()", keep.source = TRUE))
  fn_row <- which(pd$token == "SYMBOL_FUNCTION_CALL" & pd$text == "f")[1L]
  expect_false(checkhelper:::.first_arg_is_url(pd, fn_row))
})

# --- Edge branches: .first_arg_is_url() and .read_pkg_imports() -------------

test_that(".first_arg_is_url() returns FALSE when fn_row has no parent (top-level)", {
  # An artificial pd where the candidate row reports parent = 0 (no
  # surrounding expr). This shape does not occur in real parse output
  # but guards against the helper being reused on a hand-built table.
  pd <- data.frame(
    id = 1L, parent = 0L, token = "SYMBOL_FUNCTION_CALL",
    text = "GET", line1 = 1L, terminal = TRUE,
    stringsAsFactors = FALSE
  )
  expect_false(checkhelper:::.first_arg_is_url(pd, fn_row = 1L))
})

test_that(".first_arg_is_url() returns FALSE when the wrapper id has been pruned", {
  # Wrapper id 99 has no matching row in pd: the helper must bail out.
  pd <- data.frame(
    id = 1L, parent = 99L, token = "SYMBOL_FUNCTION_CALL",
    text = "GET", line1 = 1L, terminal = TRUE,
    stringsAsFactors = FALSE
  )
  expect_false(checkhelper:::.first_arg_is_url(pd, fn_row = 1L))
})

test_that(".read_pkg_imports() returns empty record on a syntactically broken NAMESPACE", {
  pkg <- tempfile("pkg-bad-ns-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  # Unclosed paren: parse() will error and the helper must fall back.
  writeLines("importFrom(httr, GET", file.path(pkg, "NAMESPACE"))

  imports <- checkhelper:::.read_pkg_imports(pkg)
  expect_equal(imports$by_symbol, list())
  expect_equal(imports$fully_imported, character(0L))
})

test_that(".read_pkg_imports() skips non-call NAMESPACE entries", {
  pkg <- tempfile("pkg-mixed-ns-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  # A bare symbol at top level is a syntactically legal expression but
  # not a call; the helper must skip it without erroring.
  writeLines(
    c(
      "42",
      "importFrom(httr, GET)"
    ),
    file.path(pkg, "NAMESPACE")
  )

  imports <- checkhelper:::.read_pkg_imports(pkg)
  expect_equal(imports$by_symbol[["GET"]], "httr")
})

test_that(".read_pkg_imports() returns empty record when NAMESPACE is missing", {
  pkg <- tempfile("pkg-no-ns-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  imports <- checkhelper:::.read_pkg_imports(pkg)
  expect_equal(imports$by_symbol, list())
  expect_equal(imports$fully_imported, character(0L))
})
