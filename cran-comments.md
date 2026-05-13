## Submission summary

This is a feature release of {checkhelper} (1.0.0). The previous CRAN
version was 0.1.0. The release introduces a uniform `audit_*` /
`fix_*` API for CRAN-blocking issues (globals, roxygen tags,
non-ASCII, userspace leaks, CRAN-settings checks, undocumented
datasets, old-style CITATION, `\dontrun{}` blocks, unquoted package
names in DESCRIPTION, network/download calls) plus a one-pass
`check_n_covr()` helper. The 10 historic functions remain callable
behind `lifecycle::deprecate_warn()` and delegate to the new
facades, so no reverse dependency breaks. See `NEWS.md` for the
full mapping.

The maintainer changes from Sebastien Rochette to Vincent Guyader.
Sebastien Rochette stays in `Authors@R` with a `previous maintainer`
note in `comment =`.

## Test environments

* local: Ubuntu Linux, R-release
* GitHub Actions: ubuntu-latest, macos-latest, windows-latest
  (R-release and R-devel)
* win-builder: R-release and R-devel

## R CMD check results

0 errors | 0 warnings | 0 notes

## Reverse dependencies

We checked the reverse dependencies of {checkhelper} on CRAN. No
breakage detected: the deprecated functions still dispatch to the
new facades with a `lifecycle::deprecate_warn()` and an unchanged
return shape.
