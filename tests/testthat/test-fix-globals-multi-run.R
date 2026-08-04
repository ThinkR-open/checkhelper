# Multi-run coverage for `fix_globals(write = TRUE)`. The 1-run paths
# and the empty-fresh re-run path are covered by
# `test-fix-globals-merge.R` and `test-fix-globals.R`. This file
# locks in the contract under repeated invocations with varying
# shapes - accumulation across runs, dedup, idempotence, manual user
# edits between runs, real round-trip, and operator-only persistence.
# Issue #127.

local_pkg_with_globals <- function(envir = parent.frame()) {
  path <- tempfile("pkg-multirun-")
  dir.create(file.path(path, "R"), recursive = TRUE)
  withr::defer(unlink(path, recursive = TRUE), envir = envir)
  path
}

# Build a `.get_no_visible()` return list with a tibble of variables
# grouped by `fun` and (optionally) a tibble of functions. The
# `operators` tibble is filled in by `.get_no_visible()` from the same
# notes shape; the multi-run tests never need it directly.
fake_check_result <- function(vars_by_fun = list(),
                              funs_by_fun = list()) {
  vars_tbl <- if (length(vars_by_fun) == 0L) {
    tibble::tibble(fun = character(0), variable = character(0))
  } else {
    tibble::tibble(
      fun = rep(names(vars_by_fun), lengths(vars_by_fun)),
      variable = unlist(vars_by_fun, use.names = FALSE)
    )
  }
  funs_tbl <- if (length(funs_by_fun) == 0L) {
    tibble::tibble(
      fun = character(0), variable = character(0),
      proposed = character(0)
    )
  } else {
    tibble::tibble(
      fun = rep(names(funs_by_fun), lengths(funs_by_fun)),
      variable = unlist(funs_by_fun, use.names = FALSE),
      proposed = NA_character_
    )
  }
  list(globalVariables = vars_tbl, functions = funs_tbl)
}

# Read the variable names actually declared in a globals.R file
# (via the package's own AST-walker, so we mirror what
# `extract_existing_globals()` sees on re-run).
declared_names <- function(path) {
  sort(checkhelper:::extract_existing_globals(path))
}

# Scenario A: 2 runs, the 2nd run brings genuinely new variables on
# top of a curated 1st-run globals.R. The 2nd run must accumulate -
# every 1st-run name still declared, every new name added, no
# duplicate at runtime.
test_that("multi-run A: 2nd run with new vars accumulates without losing 1st-run names", {
  local_quiet()
  path <- local_pkg_with_globals()
  globals_path <- file.path(path, "R", "globals.R")

  run1 <- fake_check_result(vars_by_fun = list(
    basecout_export = c("dsclin", "dsrea"),
    calculer_duree_sejour = c("dsp", "finess")
  ))
  run2 <- fake_check_result(vars_by_fun = list(
    creer_table_sejrea = c("duree", "phase"),
    importer_fichier = c("typenr")
  ))

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) run1,
    .package = "checkhelper"
  )

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) run2,
    .package = "checkhelper"
  )

  after <- declared_names(globals_path)
  expect_setequal(after, c("dsclin", "dsrea", "dsp", "finess",
                           "duree", "phase", "typenr"))

  second_run <- paste(readLines(globals_path), collapse = "\n")

  expect_match(second_run, "# creer_table_sejrea:",
    info = "new fun's `# <fun>:` group must be emitted"
  )
  expect_match(second_run, "# importer_fichier:",
    info = "every new fun must get its own `# <fun>:` group"
  )
})

# Scenario B: 2 runs, the 2nd run's check resurfaces a variable
# already covered by globals.R. The on-disk file may carry a literal
# duplicate of the shared name (1 occurrence in the fresh block, 1
# in the `# previously declared:` chunk - the merge does not strip
# preserved against fresh); the contract under test is the runtime
# set that R CMD check actually sees, which `eval()` of the
# `globalVariables(unique(c(...)))` body gives back deduplicated.
test_that("multi-run B: overlap between runs collapses at runtime via the unique() wrapper", {
  local_quiet()
  path <- local_pkg_with_globals()
  globals_path <- file.path(path, "R", "globals.R")

  run1 <- fake_check_result(vars_by_fun = list(
    fn_a = c("shared", "only_in_run1")
  ))
  run2 <- fake_check_result(vars_by_fun = list(
    fn_b = c("shared", "only_in_run2")
  ))

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) run1,
    .package = "checkhelper"
  )

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) run2,
    .package = "checkhelper"
  )

  # Bypass `declared_names()` (which dedups via the AST extractor's
  # `unique()`) and assert directly on what `eval()` of the
  # `globalVariables(unique(c(...)))` body returns - that is what R
  # CMD check actually consumes. The on-disk file may carry a
  # textual duplicate of `shared`; the runtime semantics must not.
  exprs <- parse(file = globals_path)
  collected <- character(0)
  for (i in seq_along(exprs)) {
    if (is.call(exprs[[i]])) {
      collected <- c(collected, eval(exprs[[i]][[2]]))
    }
  }
  expect_setequal(collected, c("shared", "only_in_run1", "only_in_run2"))
  expect_equal(sum(collected == "shared"), 1L,
    info = "the runtime `unique()` wrapper must collapse the on-disk duplicate of `shared`"
  )
})

# Scenario C: the file must converge by run 2. After run 1 establishes
# `globals.R`, run 2 (no new vars) leaves the file untouched; run 3
# (no new vars again) must yield byte-identical content, locking in
# the post-#125 early-return as idempotent across consecutive no-op
# passes.
test_that("multi-run C: consecutive no-op runs yield byte-identical globals.R (idempotence)", {
  local_quiet()
  path <- local_pkg_with_globals()
  globals_path <- file.path(path, "R", "globals.R")

  run <- fake_check_result(vars_by_fun = list(
    fn = c("aaa", "bbb")
  ))

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) run,
    .package = "checkhelper"
  )

  empty_run <- fake_check_result()

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) empty_run,
    .package = "checkhelper"
  )
  after_run2 <- readLines(globals_path)

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) empty_run,
    .package = "checkhelper"
  )
  after_run3 <- readLines(globals_path)

  expect_identical(after_run2, after_run3,
    info = "fix_globals must be idempotent across repeated no-op runs"
  )
})

# Scenario D: user edits globals.R manually between runs - adds a name
# not detected by R CMD check, plus a free-form comment. The next
# `fix_globals(write = TRUE)` must preserve the manually-added name.
# Comment preservation is NOT promised by the current AST-based
# extractor; assert it explicitly so the contract is visible.
test_that("multi-run D: user-curated names survive a subsequent fix_globals run", {
  local_quiet()
  path <- local_pkg_with_globals()
  globals_path <- file.path(path, "R", "globals.R")

  run1 <- fake_check_result(vars_by_fun = list(
    fn = c("detected_a")
  ))

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) run1,
    .package = "checkhelper"
  )

  curated <- readLines(globals_path)
  curated <- sub(
    "^utils::globalVariables\\(unique\\(c\\(",
    "# user-curated marker comment\nutils::globalVariables(unique(c(\n\"user_added_var\", ",
    curated
  )
  writeLines(curated, globals_path)

  run2 <- fake_check_result(vars_by_fun = list(
    fn = c("detected_b")
  ))

  testthat::with_mocked_bindings(
    fix_globals(pkg = path, write = TRUE),
    .get_no_visible = function(...) run2,
    .package = "checkhelper"
  )

  after <- declared_names(globals_path)
  expect_true("user_added_var" %in% after,
    info = "manually-added name must survive subsequent fix_globals runs"
  )
  expect_true("detected_a" %in% after,
    info = "names from the 1st automated run must survive"
  )
  expect_true("detected_b" %in% after,
    info = "names from the 2nd automated run must be added"
  )

  # Comment loss is the documented contract today: the AST extractor
  # only round-trips string literals from `globalVariables()` calls,
  # everything else gets dropped on rewrite. Lock the loss in so any
  # future change that DOES preserve comments has to revisit this
  # assertion consciously.
  after_text <- readLines(globals_path)
  expect_false(
    any(grepl("user-curated marker comment", after_text, fixed = TRUE)),
    info = "comment loss between runs is tolerated for now; update when the contract changes"
  )
})

# Scenario E: real round-trip with `create_example_pkg()`. The 2nd
# pass of `fix_globals(write = TRUE)` must be a filesystem no-op:
# globals.R content is byte-identical before / after. This is the
# failure mode that motivated #123 - a real package that never
# converges. `skip_on_cran()` because we shell out to `rcmdcheck()`.
test_that("multi-run E: real round-trip with create_example_pkg converges on the 2nd pass", {
  skip_on_cran()
  local_tempdir_clean()
  local_quiet()
  path <- quiet_create_example_pkg()
  on.exit(unlink(path, recursive = TRUE), add = TRUE)
  globals_path <- file.path(path, "R", "globals.R")

  suppressWarnings(suppressMessages(fix_globals(pkg = path, write = TRUE)))
  expect_true(file.exists(globals_path))
  pass1 <- readLines(globals_path)

  suppressWarnings(suppressMessages(fix_globals(pkg = path, write = TRUE)))
  pass2 <- readLines(globals_path)

  expect_identical(pass1, pass2,
    info = "the 2nd fix_globals pass on a curated package must be a filesystem no-op"
  )
})

# Scenario F: every check note is a function / operator note (zero
# variable notes), N runs in a row. `R/globals.R` must never be
# created and `liste_funs` (and `liste_operators` if present) must
# be surfaced on every run.
test_that("multi-run F: function-only notes on N consecutive runs never write globals.R", {
  local_quiet()
  path <- local_pkg_with_globals()
  globals_path <- file.path(path, "R", "globals.R")

  fun_only <- fake_check_result(funs_by_fun = list(
    fn = c("where", "summarise")
  ))

  msgs1 <- testthat::with_mocked_bindings(
    {
      testthat::capture_messages(
        fix_globals(pkg = path, write = TRUE)
      )
    },
    .get_no_visible = function(...) fun_only,
    .package = "checkhelper"
  )
  expect_false(file.exists(globals_path),
    info = "run 1: function-only notes must not create globals.R"
  )
  expect_true(any(grepl("where", msgs1, fixed = TRUE)),
    info = "run 1: liste_funs must surface `where`"
  )
  expect_true(any(grepl("summarise", msgs1, fixed = TRUE)),
    info = "run 1: liste_funs must surface `summarise` independently"
  )

  msgs2 <- testthat::with_mocked_bindings(
    {
      testthat::capture_messages(
        fix_globals(pkg = path, write = TRUE)
      )
    },
    .get_no_visible = function(...) fun_only,
    .package = "checkhelper"
  )
  expect_false(file.exists(globals_path),
    info = "run 2: function-only notes must still not create globals.R"
  )
  expect_true(any(grepl("where", msgs2, fixed = TRUE)),
    info = "run 2: liste_funs must surface `where` on every consecutive run"
  )
  expect_true(any(grepl("summarise", msgs2, fixed = TRUE)),
    info = "run 2: liste_funs must surface `summarise` on every consecutive run"
  )
})
