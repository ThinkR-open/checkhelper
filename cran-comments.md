## Submission summary

This is a patch release of {checkhelper} (1.0.1). The previous CRAN
version was 1.0.0.

It fixes the test failure on the r-devel Fedora flavors that
triggered the CRAN archival notice. The failure was caused by
{roxygen2} 8.0.0 migrating the `RoxygenNote` DESCRIPTION field to
`Config/roxygen2/version`, which broke a {usethis}-based test
scaffolding step. The test suite has been fixed, a regression test
added, and the declared dependencies aligned ({roxygen2} >= 7.3.0,
R >= 4.1). The test suite passes with both {roxygen2} 8.1.0 and
7.3.3. See `NEWS.md` for details.

## Test environments

* local: Ubuntu Linux, R-release, roxygen2 8.1.0
* GitHub Actions: ubuntu-latest (R-devel, R-release, R-oldrel),
  macos-latest (R-release), windows-latest (R-release)
* win-builder: R-devel

## R CMD check results

0 errors | 0 warnings | 0 notes

## Reverse dependencies

No API change in this release: only tests, documentation, and
declared dependency floors were touched.
