# checkhelper (development version)

## Minor changes

- `asciify_pkg()` now prints a one-line summary of how many files were
  scanned, changed, and how many non-ASCII characters were found. In
  dry-run mode it also prints how to apply the rewrite and how to
  inspect the per-file detail. Use `suppressMessages()` to silence.
- `asciify_pkg()` and `asciify_file()` gain an `n_chars` column /
  list element: the count of non-ASCII characters in the original
  file. `n_tokens` (number of source locations to rewrite) is kept.

# checkhelper 1.0.0

## New features

- `asciify_pkg()`, `asciify_file()`, `asciify_r_source()`,
  `find_nonascii_tokens()` and `find_nonascii_files()` rewrite
  non-ASCII characters in an R package the way CRAN expects: `\uXXXX`
  escapes in string literals, `Latin-ASCII` transliteration in
  comments and roxygen blocks, refusal to auto-rename non-ASCII
  identifiers. AST-based via `getParseData()`. Defaults to a dry run
  for whole-package rewrites.

# checkhelper 0.1.1

## Bug fixes 

- Modification of unit tests following {roxygen2} changes. `find_missing_values` only return messages instead of warnings. (@MurielleDelmotte) 

# checkhelper 0.1.0

## Major changes

- Check that there is no new file after tests, examples, vignettes of full check with `check_clean_userspace()` (#13)

## Minor changes

- Clean userspace after examples and tests
- Export `create_example_pkg()` to get examples in functions documentation

## Bring the package up to standard (#25)

- Modify the LICENCE to MIT
- Update Code Of Conduct to a recent version
- Add a package documentation
- Update Github Actions workflows

# checkhelper 0.0.1

- Check with same variables and parameters as CRAN with `check_as_cran()` (#21)
- Find missing tags in your roxygen skeletons with `find_missing_tags()`
- Print code to add to 'globals.R' with `print_globals()`
- Extract "no visibles" from notes of `rcmdcheck()`
- Added a `NEWS.md` file to track changes to the package.
