# Regression tests for audit_dontrun() (#72).
#
# CRAN policy: \dontrun{} should only wrap example code that genuinely
# cannot be executed (missing API key, missing system dependency, side
# effect on user filespace). Otherwise the contributor should use
# \donttest{}, which still gets exercised by `R CMD check --run-donttest`
# but is skipped by default. audit_dontrun() walks man/*.Rd and surfaces
# every \dontrun{} block so the contributor can review each one.

local_pkg_with_rd <- function(rd_files, envir = parent.frame()) {
  path <- tempfile("pkg-dontrun-")
  dir.create(file.path(path, "man"), recursive = TRUE)
  for (name in names(rd_files)) {
    writeLines(rd_files[[name]], file.path(path, "man", name))
  }
  withr::defer(unlink(path, recursive = TRUE), envir = envir)
  path
}

test_that("audit_dontrun() flags every \\dontrun{} block", {
  pkg <- local_pkg_with_rd(list(
    "foo.Rd" = c(
      "\\name{foo}",
      "\\title{Foo}",
      "\\examples{",
      "x <- 1",
      "\\dontrun{",
      "  hard_to_run_thing()",
      "}",
      "}"
    ),
    "bar.Rd" = c(
      "\\name{bar}",
      "\\title{Bar}",
      "\\examples{",
      "\\dontrun{",
      "  another_one()",
      "}",
      "\\dontrun{",
      "  and_again()",
      "}",
      "}"
    )
  ))

  out <- audit_dontrun(pkg)

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("rd_file", "topic", "line", "suggestion"))
  expect_equal(nrow(out), 3L)
  expect_setequal(out$rd_file, c("foo.Rd", "bar.Rd"))
  expect_setequal(out$topic, c("foo", "bar"))
  expect_true(all(out$line >= 1L))
  expect_match(out$suggestion[1], "\\\\donttest", fixed = FALSE)
})

test_that("audit_dontrun() returns empty tibble when no \\dontrun is present", {
  pkg <- local_pkg_with_rd(list(
    "modern.Rd" = c(
      "\\name{modern}",
      "\\title{Modern}",
      "\\examples{",
      "\\donttest{",
      "  x <- 1",
      "}",
      "}"
    )
  ))

  out <- audit_dontrun(pkg)

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("rd_file", "topic", "line", "suggestion"))
  expect_equal(nrow(out), 0L)
})

test_that("audit_dontrun() handles a missing man/ directory gracefully", {
  pkg <- tempfile("pkg-no-man-")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  expect_message(out <- audit_dontrun(pkg), regexp = "no man/")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
})

test_that("audit_dontrun() emits a cli summary message", {
  pkg <- local_pkg_with_rd(list(
    "foo.Rd" = c(
      "\\name{foo}",
      "\\title{Foo}",
      "\\examples{",
      "\\dontrun{",
      "  x <- 1",
      "}",
      "}"
    )
  ))

  expect_message(audit_dontrun(pkg), regexp = "audit_dontrun")
})

test_that("audit_dontrun() reports correct line numbers", {
  pkg <- local_pkg_with_rd(list(
    "foo.Rd" = c(
      "\\name{foo}",        # 1
      "\\title{Foo}",       # 2
      "\\examples{",        # 3
      "x <- 1",             # 4
      "\\dontrun{",         # 5  <-- expected line
      "  hard_thing()",     # 6
      "}",                  # 7
      "}"                   # 8
    )
  ))

  out <- audit_dontrun(pkg)
  expect_equal(nrow(out), 1L)
  expect_equal(out$line, 5L)
})

test_that("audit_dontrun() ignores commented-out \\dontrun mentions", {
  # A `% \dontrun{` (Rd comment) must not trigger a false positive.
  pkg <- local_pkg_with_rd(list(
    "foo.Rd" = c(
      "\\name{foo}",
      "\\title{Foo}",
      "% \\dontrun{ historical comment }",
      "\\examples{",
      "x <- 1",
      "}"
    )
  ))

  out <- audit_dontrun(pkg)
  expect_equal(nrow(out), 0L)
})

# --- Edge / coverage tests --------------------------------------------------

test_that("audit_dontrun() handles empty man/ directory (no Rd files)", {
  pkg <- tempfile("pkg-empty-man-")
  dir.create(file.path(pkg, "man"), recursive = TRUE)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  expect_message(out <- audit_dontrun(pkg), regexp = "no Rd files")
  expect_equal(nrow(out), 0L)
})

test_that(".scan_one_rd_for_dontrun() warns and skips when readLines fails", {
  # Passing a directory path to readLines() raises an error that the
  # internal tryCatch must surface as a warning, then return NULL.
  bad_path <- tempfile("bad-rd-")
  dir.create(bad_path)
  on.exit(unlink(bad_path, recursive = TRUE), add = TRUE)

  expect_warning(
    res <- checkhelper:::.scan_one_rd_for_dontrun(bad_path),
    regexp = "Could not read"
  )
  expect_null(res)
})

test_that(".scan_one_rd_for_dontrun() returns NULL on empty file", {
  empty_rd <- tempfile(fileext = ".Rd")
  file.create(empty_rd)
  on.exit(unlink(empty_rd), add = TRUE)

  expect_null(checkhelper:::.scan_one_rd_for_dontrun(empty_rd))
})

test_that(".topic_from_rd() falls back to basename when \\name is missing", {
  topic <- checkhelper:::.topic_from_rd(
    lines = c("\\title{x}", "\\examples{}"),
    fallback = "my_fallback"
  )
  expect_equal(topic, "my_fallback")
})
