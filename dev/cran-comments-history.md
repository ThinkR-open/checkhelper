# checkhelper 0.1.0

## R CMD check results

* Tested on GitHub Actions, {rhub} and Win-devel and Mac-release
* Fixed the previous error on submission concerning the number of CPU used.

0 errors | 0 warnings | 1 note

* There is one note because this is a new package.

## Address CRAN comments

- If there are references describing the methods in your package, please
add these in the description field of your DESCRIPTION file in the form
authors (year) doi:...
authors (year) arXiv:...
authors (year, ISBN:...)
or if those are not available: https:...
with no space after 'doi:', 'arXiv:', 'https:' and angle brackets for
auto-linking. (If you want to add a title as well please put it in
quotes: "Title")
=> We added link to CRAN GitHub mirror as `@references` where URL was presented.

- Please add \value to .Rd files regarding exported methods and explain
the functions results in the documentation. Please write about the
structure of the output (class) and also what the output means. (If a
function does not return a value, please document that too, e.g.
\value{No return value, called for side effects} or similar)
Missing Rd-tags:
pipe.Rd: \value
=> @return tag was added to the R script

- \dontrun{} should only be used if the example really cannot be executed
(e.g. because of missing additional software, missing API keys, ...) by
the user. That's why wrapping examples in \dontrun{} adds the comment
("# Not run:") as a warning for the user. Does not seem necessary.
Please replace \dontrun with \donttest.
Please unwrap the examples if they are executable in < 5 sec, or replace
\dontrun{} with \donttest{}.
=> We keep the use of \dontrun in majority in our examples. There are required in our function documentation because we cannot let open the possibility that checks may be run on the \donttest as we know they will fail. Indeed, we run checks inside checks which make it difficult to account for the side-effects on CRAN machines. The real use by users will be a direct use during their package development and the majority of these examples will have a direct effect on their current project. 


- Please ensure that your functions do not write by default or in your
examples/vignettes/tests in the user's home filespace (including the
package directory and getwd()). This is not allowed by CRAN policies.
Please omit any default path in writing functions. In your
examples/vignettes/tests you can write to tempdir(). -> R/check_as_cran.R
=> check_as_cran() is now tested on a package saved in a temporary directory.
