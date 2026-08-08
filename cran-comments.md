## Submission summary

This is a patch release of {checkhelper} (1.0.1). The previous CRAN
version was 1.0.0.

It fixes the test failure that triggered the archival notice. The
failure is not flavor specific: it is currently reported on the four
r-devel Linux flavors (debian and fedora, clang and gcc),
r-patched-linux-x86_64, r-release-windows-x86_64 and
r-oldrel-windows-x86_64, that is on every flavor that has already
picked up {roxygen2} 8.x.

The cause is {roxygen2} 8.0.0 migrating the `RoxygenNote` DESCRIPTION
field to `Config/roxygen2/version`. {usethis} (<= 3.2.1) still detects
roxygen through the old field, so a {usethis}-based test scaffolding
step aborted with "does not use roxygen2". The test suite has been
fixed, a regression test added, and the declared dependencies aligned
({roxygen2} >= 7.3.0, R >= 4.1). The test suite passes with both
{roxygen2} 8.1.0 and 7.3.3. See `NEWS.md` for details.

## Test environments

* local: Windows 11, R 4.5.0, checked twice, once with roxygen2 7.3.3
  and once with roxygen2 8.1.0
* GitHub Actions: ubuntu-latest (R-devel, R-release, R-oldrel),
  macos-latest (R-release), windows-latest (R-release), all with
  roxygen2 8.1.0
* win-builder: R-devel

## R CMD check results

0 errors | 0 warnings | 0 notes

## Reverse dependencies

No API change in this release: only tests, documentation, and
declared dependency floors were touched.
