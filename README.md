
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![checkhelper status
badge](https://thinkr-open.r-universe.dev/badges/checkhelper)](https://thinkr-open.r-universe.dev)
[![R-CMD-check](https://github.com/ThinkR-open/checkhelper/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ThinkR-open/checkhelper/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/ThinkR-open/checkhelper/branch/main/graph/badge.svg)](https://app.codecov.io/gh/ThinkR-open/checkhelper/tree/main)
[![](https://cranlogs.r-pkg.org/badges/checkhelper)](https://cran.r-project.org/package=checkhelper)
[![CRAN
status](https://www.r-pkg.org/badges/version/checkhelper)](https://CRAN.R-project.org/package=checkhelper)
<!-- badges: end -->

# checkhelper

A toolkit for R package authors that turns each `R CMD check` warning
or NOTE into a clear two-step workflow: **audit** what the issue is,
then **fix** it. The goal is to reduce the risk of CRAN rejection.

Complete documentation in the {pkgdown} site:
<https://thinkr-open.github.io/checkhelper/>

## API at a glance

Each category of CRAN issue gets one read-only `audit_*()` function
and, when an automated fix is safe, one `fix_*()` function. Type
`audit_<TAB>` or `fix_<TAB>` in RStudio to discover the surface.

| CRAN issue | Audit (read-only) | Fix (action) |
|---|---|---|
| Globals to declare (`no visible binding`) | `audit_globals()` | `fix_globals()` |
| Missing roxygen tags (`@return`, `@noRd`) | `audit_tags()` | — |
| Non-ASCII characters | `audit_ascii()` | `fix_ascii()` |
| Files left in user space by checks | `audit_userspace()` | — |
| `R CMD check` with CRAN settings | `audit_check()` | — |
| Undocumented datasets | `audit_dataset_doc()` | `fix_dataset_doc()` |

Lower-level helpers (`asciify_file()`, `asciify_r_source()`,
`find_nonascii_tokens()`, `create_example_pkg()`) are also exported
for fine-grained scripting.

The 10 historic functions (`get_no_visible()`, `find_missing_tags()`,
`asciify_pkg()`, `check_as_cran()`, …) remain callable but emit a
`lifecycle::deprecate_warn()` and delegate to the new façades — see
`NEWS.md` for the full mapping.

## Installation

From CRAN:

``` r
install.packages("checkhelper")
```

Latest from r-universe:

``` r
install.packages("checkhelper", repos = "https://thinkr-open.r-universe.dev")
```

From GitHub:

``` r
remotes::install_github("thinkr-open/checkhelper")
```

## Quick start

`create_example_pkg()` ships a fake package that already trips most of
the checks `checkhelper` covers. Use it to feel the workflow:

``` r
library(checkhelper)

pkg <- create_example_pkg()

# Find exported functions missing @return / documented internals missing @noRd
audit_tags(pkg)

# Surface globals to declare (slow: runs R CMD check under the hood)
audit_globals(pkg)

# Then either print the globalVariables() block or write it to R/globals.R
fix_globals(pkg)
fix_globals(pkg, write = TRUE)

# Find non-ASCII characters across R/, tests/, vignettes/, man/, DESCRIPTION
audit_ascii(pkg)

# Rewrite them CRAN-cleanly (escape literals, transliterate comments).
# Dry-run by default — pass dry_run = FALSE to apply.
fix_ascii(pkg, dry_run = FALSE)
```

For the full walkthrough per issue category, see the vignettes on the
pkgdown site.

## Code of Conduct

Please note that the checkhelper project is released with a [Contributor
Code of
Conduct](https://thinkr-open.github.io/checkhelper/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
