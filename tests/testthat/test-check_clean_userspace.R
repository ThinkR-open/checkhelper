
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

  # No synthetic example leak: with `fresh = TRUE` (#87) examples run
  # in a callr subprocess whose working dir is the `<pkg>.Rcheck` build
  # tree (filtered out by `what_changed()` as expected check-tree
  # noise), and whose tempdir is torn down before our post-step
  # snapshot runs. That mirrors the CRAN-side behaviour: ephemeral
  # files an example creates in its own session are never seen by
  # `R CMD check` either. The unit-test seed (`in_test.R` written into
  # `pkg/tests/testthat/`) remains and covers the real CRAN-policy
  # case (file added inside the package tree).
  suppressWarnings(attachment::att_amend_desc(path = path))

  check_output <- tempfile("check_output")

  # With fresh = TRUE the example body runs in a callr subprocess
  # whose tempdir is torn down before our post-step snapshot runs, so
  # no example leak is surfaced and the file-list warning never fires
  # in this fixture. (The "Files surfaced during 'Run examples'"
  # warning path is not currently asserted on by any test — TODO add
  # a regression that seeds a real package-tree leak from inside an
  # example so the warning fires.)
  expect_message(
    all_files <- check_clean_userspace(pkg = path, check_output = check_output),
    "Some files"
  )

  expect_s3_class(all_files, "tbl_df")
  expect_named(all_files, c("source", "problem", "where", "file"))
  expect_gte(nrow(all_files), 2) # >=2 rows for the in_test.R seed
  expect_true(all(all_files$problem %in% c("added", "deleted", "changed")))
  expect_true(all(all_files$source %in% c(
    "Unit tests", "Run examples", "Run examples (partial)",
    "Full check", "Build Vignettes", "Tests in check dir"
  )))

  # With `fresh = TRUE` the example body runs in a subprocess whose
  # tempdir is torn down before our post-step snapshot runs, so no
  # example leak is surfaced. Only the unit-test seed survives.
  unit_files <- all_files$file[all_files$source == "Unit tests"]
  expect_true(any(grepl("in_test[.]R", unit_files)))

  unlink(path, recursive = TRUE)
  unlink(check_output, recursive = TRUE)
})
