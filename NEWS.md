# checkhelper (development version)

## `audit_description()`: catch unquoted package names in DESCRIPTION

- New `audit_description(pkg)` reads the `Description` field of
  `DESCRIPTION`, tokenises it, and surfaces every word that matches
  an installed package name yet is not wrapped in single quotes.
  CRAN incoming pretest emits
  `Package names should be quoted in the Description field` when
  this rule is violated. Detection is purely static: no package is
  loaded, no namespace is touched. The package's own name and
  compound forms (`dplyr-style`, `httr2-based`, ...) are
  intentionally not flagged. Returns a tibble with `word`,
  `position` and `suggestion`. Closes #52.

## `audit_dontrun()`: surface every `\dontrun{}` block in `man/*.Rd`

- New `audit_dontrun(pkg)` walks `man/*.Rd` line by line and surfaces
  every `\dontrun{}` block, with the source Rd file, the documented
  topic, the line number and a one-line suggestion to switch to
  `\donttest{}` unless the example genuinely cannot be executed
  (missing API key, missing system dependency, side effect on the
  user's filespace). Detection is purely static: each Rd file is
  read line-by-line and never sourced. Closes #72.

## `fix_globals()` separates operators / pronouns from real globals

- `:=`, `.SD`, `.N`, `.I`, `.GRP`, `.BY`, `.EACHI` (data.table),
  `.data`, `.env`, `!!`, `!!!` (rlang) are no longer routed into the
  `utils::globalVariables(c(...))` block. They are exports from
  another package - not undeclared variables - and the right fix is
  an `@importFrom` line, not a `globalVariables()` entry.
- `audit_globals()` / `.get_no_visible()` now return a third tibble
  `operators` next to `globalVariables` and `functions`. The token
  is paired with its candidate source package(s).
- `fix_globals()` prints a third section
  *"Operators / pronouns to import via NAMESPACE"* with ready-to-paste
  `#' @importFrom <pkg> <token>` lines. When the source is ambiguous
  (`:=` is exported by both data.table and rlang) every candidate is
  listed and the user picks one consciously - no silent guessing.
- `fix_globals(write = TRUE)` only writes real globals to
  `R/globals.R`. The operators section is printed on stdout so the
  user wires the `@importFrom` lines into NAMESPACE manually.
- The internal regex that extracts the function name from a check
  note (`fun = str_extract(fun, ".+(?=:)")`) was greedy and ate the
  whole prose of `:=` notes. Anchored to the first `:` so it now
  reports the actual caller.

## `fix_globals(write = TRUE)` now merges with the existing `R/globals.R`

- Previously, `fix_globals(write = TRUE)` overwrote `R/globals.R`
  with a fresh `utils::globalVariables(unique(c(...)))` block. That
  was unsafe: `R CMD check` already filters out names covered by an
  existing `globalVariables()` call, so the second time
  `fix_globals()` ran on a curated package, only the *uncovered*
  names showed up in the notes - overwriting then erased every
  previously-declared name and re-flagged it on the next check
  (circular game).
- The function now parses the existing `R/globals.R`, extracts the
  names from any `globalVariables()` / `utils::globalVariables()`
  calls it finds, and rewrites the file as the deduplicated union
  of the freshly detected names and the already-declared ones. The
  preserved block is appended under a `# previously declared:`
  banner inside the same `unique(c(...))` payload.

## `audit_userspace()` / `check_clean_userspace()` robustness

- The `Run examples` step is now wrapped in a `tryCatch()`. When
  `devtools::run_examples()` fails deep inside `pkgload` (e.g. the
  `srcrefs[[1L]]: subscript out of bounds` crash on `@examplesIf`
  examples whose body is fully under `\donttest{}`, on older R +
  pkgload combos), the audit no longer aborts: it warns, skips the
  examples slice, and still runs the unit tests / full check /
  vignettes steps (#93).
- On a partial run, the snapshot diff is still computed (rows tagged
  `source = "Run examples (partial)"`) so files created before the
  crash do not slip into the next baseline and disappear from the
  report.
- The follow-up warning that surfaces files added during examples
  now lists the files instead of telling the user to "not bother
  about it" - a real leak written from inside an example would
  previously have been silently dismissed.
- `tests/testthat/test-check_clean_userspace.R` no longer hardcodes a
  `nrow == 5/6/11` cascade. It asserts the invariants the function
  promises (the seeded leaks are caught, every row has the right
  shape) instead of an exact OS-dependent row count, so the test now
  runs on every OS (#54).

## `audit_citation()`: catch CRAN-rejected old-style CITATION calls

- New `audit_citation(pkg)` parses `inst/CITATION` statically (no
  `eval()`) and surfaces every call to `personList()`,
  `as.personList()` or `citEntry()` that CRAN rejects on submission
  (`Package CITATION file contains call(s) to old-style ...`).
  Returns a tibble with `call`, `line` and a one-line `suggestion`
  for the modern equivalent (`c()` on `person()` objects;
  `bibentry()` instead of `citEntry()`). Closes #62.

## `audit_globals()` / `fix_globals()` skip vignettes / tests / examples

- The internal `R CMD check` triggered by `audit_globals()` and
  `fix_globals()` now passes
  `build_args = "--no-build-vignettes"` and
  `args = c("--no-manual", "--no-tests", "--no-examples", "--no-vignettes")`.
  The "no visible binding for global variable" /
  "no visible global function definition" notes come from R CMD
  check's static `* checking R code for possible problems` step
  and never depended on those phases. On a vignette-heavy package
  this turns a multi-minute wait into a few seconds. The defaults
  are exposed as `build_args` / `args` arguments to `.get_notes()`
  so a caller can still opt back in if needed.

## `audit_tags()` / `find_missing_tags()` now detect S3 cases

- `audit_tags()` and `find_missing_tags()` now flag missing `@return`
  on S3 generics and on S3 methods that have their own Rd file
  (block carrying a title or `@rdname` / `@describeIn` / `@name`).
  Previously a strict `class(object)[1] == "function"` filter dropped
  these blocks silently, so packages like the one reported in #92
  were told "Good!" while CRAN was still asking for `\value` on
  generics' Rd files (e.g. `strand_chr.Rd`,
  `dim.gggenomes_layout.Rd`).
- Bare-`@export` blocks (no title, no `@rdname` / `@describeIn` /
  `@name`) are intentionally not flagged: they produce no Rd file and
  CRAN does not ask for `\value` on them.

## `create_example_pkg()` covers every audit

- `create_example_pkg()` gains two opt-in flags so the same one-line
  fixture can demonstrate every audit:
  - `with_nonascii = TRUE` copies a French-flavoured `R/nonascii.R`
    (accents in comments + string literals + a `message()` body) so
    `audit_ascii()` and `fix_ascii()` have something to surface.
  - `with_undocumented_data = TRUE` writes a tiny
    `data/demo_dataset.rda` without a roxygen block so
    `audit_dataset_doc()` flags it as undocumented.
- Both default to `FALSE` to keep the historic behaviour for tests.
  The `README` Quick start and the *"Auditing an R package"* vignette
  now activate them so a copy-paste demo trips every audit.

## Share one R CMD check across audits

- `audit_globals()` and `fix_globals()` gain a `checks =` argument
  that accepts a pre-computed `rcmdcheck::rcmdcheck()` result. When
  supplied, they skip running `R CMD check` and reuse the existing
  output. Lets you run the check **once** and feed both functions
  during a full package audit. See the new vignette
  *"Auditing an R package you have just received"*.

## Documentation

- Vignettes consolidated to two: *"Auditing an R package you have just
  received"* (canonical dev-time workflow with the shared `chk`
  pattern, plus a per-issue cheatsheet) and *"Pre-submission gates"*
  (heavier audits run before release: `audit_check()` and
  `audit_userspace()`). The historic per-issue vignettes
  (`deal-with-check-outputs`, `check-with-real-cran-settings`,
  `no-files-left-after-check`) have been removed; their content lives
  in those two and in the function reference.
- `README` Quick start now uses the shared-`chk` workflow as the
  default example.

## API refresh - `audit_*` / `fix_*` façades

The package now exposes a uniform CRAN-oriented API: each category of
`R CMD check` issue gets one `audit_*` (read-only) function and, when
an automated fix is safe, one `fix_*` (action) function. Type
`audit_<TAB>` or `fix_<TAB>` in RStudio to discover the surface.

| CRAN issue | Audit | Fix |
|---|---|---|
| Globals to declare (`no visible binding`) | `audit_globals()` | `fix_globals()` |
| Missing roxygen tags | `audit_tags()` | - |
| Non-ASCII characters | `audit_ascii()` | `fix_ascii()` |
| Files left in user space | `audit_userspace()` | - |
| `R CMD check` with CRAN settings | `audit_check()` | - |
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
