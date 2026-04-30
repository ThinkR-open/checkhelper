# checkhelper (development version)

## API refresh — `audit_*` / `fix_*` façades

The package now exposes a uniform CRAN-oriented API: each category of
`R CMD check` issue gets one `audit_*` (read-only) function and, when
an automated fix is safe, one `fix_*` (action) function. Type
`audit_<TAB>` or `fix_<TAB>` in RStudio to discover the surface.

| CRAN issue | Audit | Fix |
|---|---|---|
| Globals to declare (`no visible binding`) | `audit_globals()` | `fix_globals()` |
| Missing roxygen tags | `audit_tags()` | — |
| Non-ASCII characters | `audit_ascii()` | `fix_ascii()` |
| Files left in user space | `audit_userspace()` | — |
| `R CMD check` with CRAN settings | `audit_check()` | — |
| Undocumented datasets | `audit_dataset_doc()` | `fix_dataset_doc()` |

The 10 historic functions remain callable but emit
`lifecycle::deprecate_warn()` and delegate to the new façades:

| Old | → New |
|---|---|
| `find_nonascii_files()` | `audit_ascii()` |
| `asciify_pkg()` | `fix_ascii()` |
| `get_no_visible()` | `audit_globals()` |
| `print_globals()` | `fix_globals()` |
| `find_missing_tags()` | `audit_tags()` |
| `check_as_cran()` | `audit_check()` |
| `check_clean_userspace()` | `audit_userspace()` |
| `use_data_doc()` | `fix_dataset_doc()` |
| `get_notes()` | (internal) `audit_globals()` |
| `get_data_info()` | (internal) `fix_dataset_doc()` |

## Other changes

- The `%>%` re-export from `magrittr` is dropped. The pipe is no
  longer in the package's exported surface; the native pipe `|>` is
  available since R 4.1.
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
