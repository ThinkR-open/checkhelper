# Regression test: fix_globals() must not glue NSE operators / data.table
# pronouns / rlang quasiquotation tokens into the
# `utils::globalVariables(c(...))` block. Those are not undeclared
# variables — they are exports from another package and the right fix
# is `@importFrom`. See user request: `:=`, `.SD`, `.N`, `.I`, `.GRP`,
# `.BY`, `.EACHI` (data.table) and `.data`, `.env`, `!!`, `!!!`
# (rlang).

fake_check_with_notes <- function(...) {
  # R CMD check emits one big note block with many lines, not many
  # notes with one line each. Mirror that structure so .get_notes()
  # downstream parses every line we feed it.
  lines <- c(...)
  list(notes = paste0(
    "checking R code for possible problems ... NOTE\n",
    paste(lines, collapse = "\n"),
    "\n"
  ))
}

# A single check note LINE (no NOTE header, no trailing newline).
note_var <- function(fun, var) {
  paste0(fun, ": no visible binding for global variable ‘", var, "’")
}
note_fun <- function(fun, var) {
  paste0(fun, ": no visible global function definition for ‘", var, "’")
}

test_that(":= is routed to operators, not to globalVariables", {
  chk <- fake_check_with_notes(c(
    note_fun("indicator_fn", ":="),
    note_var("indicator_fn", "real_global")
  ))

  res <- checkhelper:::.get_no_visible(checks = chk)

  expect_true("operators" %in% names(res),
    info = "the no-visible struct must surface a third bucket for operators"
  )
  expect_true(":=" %in% res$operators$variable)
  expect_false(":=" %in% res$globalVariables$variable)
  expect_false(":=" %in% res$functions$variable)
  expect_true("real_global" %in% res$globalVariables$variable)

  printed <- checkhelper:::.print_globals(res, message = FALSE)

  # The Rd payload (what gets written to R/globals.R) must keep the
  # real global and drop the operator.
  expect_match(printed$liste_globals_code, "real_global", fixed = TRUE)
  expect_no_match(printed$liste_globals_code, ":=", fixed = TRUE)

  # An operators section must exist with an @importFrom suggestion.
  expect_true("liste_operators" %in% names(printed))
  expect_match(printed$liste_operators, "@importFrom", fixed = TRUE)
  expect_match(printed$liste_operators, ":=", fixed = TRUE)
})

test_that(".data and .env are routed to operators (rlang pronouns)", {
  chk <- fake_check_with_notes(c(
    note_var("my_fn", ".data"),
    note_var("my_fn", ".env"),
    note_var("my_fn", "real_col")
  ))

  res <- checkhelper:::.get_no_visible(checks = chk)
  printed <- checkhelper:::.print_globals(res, message = FALSE)

  expect_setequal(res$operators$variable, c(".data", ".env"))
  expect_setequal(res$globalVariables$variable, "real_col")

  expect_match(printed$liste_globals_code, "real_col", fixed = TRUE)
  expect_no_match(printed$liste_globals_code, ".data", fixed = TRUE)
  expect_no_match(printed$liste_globals_code, ".env", fixed = TRUE)
  expect_match(printed$liste_operators, "@importFrom rlang", fixed = TRUE)
})

test_that("data.table pronouns (.SD, .N, .I, .GRP, .BY, .EACHI) are routed to operators", {
  toks <- c(".SD", ".N", ".I", ".GRP", ".BY", ".EACHI")
  notes <- vapply(toks, function(t) note_var("dt_fn", t), character(1))
  chk <- fake_check_with_notes(notes)

  res <- checkhelper:::.get_no_visible(checks = chk)
  printed <- checkhelper:::.print_globals(res, message = FALSE)

  expect_setequal(res$operators$variable, toks)
  expect_equal(nrow(res$globalVariables), 0L)

  for (t in toks) {
    expect_no_match(printed$liste_globals_code, t, fixed = TRUE)
  }
  expect_match(printed$liste_operators, "@importFrom data.table", fixed = TRUE)
})

test_that("ambiguous source (`:=` from data.table OR rlang) lists both candidates", {
  chk <- fake_check_with_notes(note_fun("my_fn", ":="))
  printed <- checkhelper:::.print_globals(
    checkhelper:::.get_no_visible(checks = chk),
    message = FALSE
  )

  # Both candidate packages must be visible — never silently pick one.
  expect_match(printed$liste_operators, "data.table", fixed = TRUE)
  expect_match(printed$liste_operators, "rlang", fixed = TRUE)
})

test_that("plain global variables still go to utils::globalVariables() (no regression)", {
  chk <- fake_check_with_notes(c(
    note_var("fn", "var1"),
    note_var("fn", "var2")
  ))

  res <- checkhelper:::.get_no_visible(checks = chk)
  printed <- checkhelper:::.print_globals(res, message = FALSE)

  expect_equal(nrow(res$operators), 0L)
  expect_setequal(res$globalVariables$variable, c("var1", "var2"))
  expect_match(printed$liste_globals_code, "var1", fixed = TRUE)
  expect_match(printed$liste_globals_code, "var2", fixed = TRUE)
})
