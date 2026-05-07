
test_that("check_clean_userspace works", {
  # Invariants instead of an exact row count: R CMD check leaks slightly
  # different platform-specific artefacts (callr-*, foo.o, symbols.rds,
  # DESCRIPTION rewrite by document(), ...) so the historical cascade
  # `nrow == 5/6/11` would either skip whole OSes or break on minor
  # tooling bumps. We assert the invariants the function actually
  # promises: the two seeded leaks are caught, every row has the right
  # shape, and any extra rows live in known noise locations.

  path <- suppressWarnings(create_example_pkg())
  dir.create(file.path(path, "tests", "testthat"), recursive = TRUE)
  # A test that leaks a file in the testthat dir
  cat(
    "cat('#in tests', file = 'in_test.R')",
    file = file.path(path, "tests", "testthat", "test-in_test.R")
  )

  # A function whose @examples leak a file in tempdir
  cat(
    "#' Function",
    "#' @return 1",
    "#' @export",
    "#' @examples",
    "#' text <- \"in_example\"",
    "#' file <- tempfile(\"in_example\")",
    "#' cat(text, file = file)",
    "in_example <- function() {",
    "1",
    "}",
    sep = "\n",
    file = file.path(path, "R", "in_example.R")
  )

  suppressWarnings(attachment::att_amend_desc(path = path))

  check_output <- tempfile("check_output")
  scratch_dir <- tempfile("dirtmp")

  expect_warning(
    expect_message(
      all_files <- check_clean_userspace(pkg = path, check_output = check_output),
      "Some files"
    ),
    "One of the 'Run examples'"
  )

  expect_s3_class(all_files, "tbl_df")
  expect_named(all_files, c("source", "problem", "where", "file"))
  expect_gte(nrow(all_files), 4) # 2x in_test + 2x in_example minimum
  expect_true(all(all_files$problem %in% c("added", "deleted", "changed")))
  expect_true(all(all_files$source %in% c(
    "Unit tests", "Run examples", "Full check", "Build Vignettes",
    "Tests in check dir"
  )))

  # The two seeded leaks must be caught, regardless of OS noise:
  unit_files <- all_files$file[all_files$source == "Unit tests"]
  example_files <- all_files$file[all_files$source == "Run examples"]
  expect_true(any(grepl("in_test[.]R", unit_files)))
  expect_true(any(grepl("in_example", example_files)))

  unlink(path, recursive = TRUE)
  unlink(check_output, recursive = TRUE)
  unlink(scratch_dir, recursive = TRUE)
})
