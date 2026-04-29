
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

A toolkit for R package authors: surface globals to declare, audit
roxygen tags, rewrite non-ASCII characters CRAN-cleanly, and run
`R CMD check` with CRAN-equivalent settings — to reduce the risk of CRAN
rejection.

Complete documentation in the {pkgdown} site:
<https://thinkr-open.github.io/checkhelper/>

## What it does

- **Surface globals to declare** (`get_no_visible()`,
  `print_globals()`) — collects `no visible binding for global variable`
  / `no visible global function` notes from `R CMD check`, then prints
  the `globalVariables(...)` block to drop in `R/globals.R` and the
  imports to add to `NAMESPACE`.
- **Audit roxygen tags** (`find_missing_tags()`) — flags exported
  functions missing `@return`, and documented internal functions missing
  `@noRd`.
- **Rewrite non-ASCII characters** (`asciify_pkg()`,
  `find_nonascii_files()`, `asciify_file()`) — escapes string literals
  to `\uXXXX` and transliterates comments/roxygen so the package passes
  CRAN's "non-ASCII characters" check. Dry-run by default.
- **Run `R CMD check` with CRAN settings** (`check_as_cran()`) — uses
  the env vars and options from CRAN's incoming-pretest scripts.
- **Spot files left behind by checks** (`check_clean_userspace()`) —
  pinpoints which examples / tests / vignettes leak files into user
  space.
- **Document datasets** (`get_data_info()`, `use_data_doc()`) —
  generates a roxygen skeleton for a loaded dataset.

## Installation

Install from CRAN

``` r
install.packages("checkhelper")
```

You can install the last version of checkhelper from r-universe with:

``` r
install.packages('checkhelper', repos = 'https://thinkr-open.r-universe.dev')
```

Or from GitHub:

``` r
remotes::install_github("thinkr-open/checkhelper")
```

## Examples

### Directly in your package in development

- Use `checkhelper::find_missing_tags()` on your package in development
  to flag two CRAN-blocking situations:
  - exported functions with no `@return` (CRAN policy: every exported
    function must document its return value),
  - documented internal functions missing `@noRd` (these trigger the
    `Please add \value to .Rd files` CRAN message).
- Use `checkhelper::print_globals()` instead of `devtools::check()` to
  run the checks (via `rcmdcheck::rcmdcheck()`) and get a
  ready-to-paste `globalVariables(...)` block for `R/globals.R`.

``` r
checkhelper::find_missing_tags()

checkhelper::print_globals(quiet = TRUE)
```

### Reproducible example with a fake package in tempdir

- Create a fake package with
  - a function having global variables
  - a function with `@export` but no `@return`
  - a function with title but without `@export` and thus missing `@noRd`

``` r
library(checkhelper)

# Create fake package ----
pkg_path <- tempfile(pattern = "pkg.")
dir.create(pkg_path)

# Create fake package
usethis::create_package(pkg_path, open = FALSE)
#> ✔ Setting active project to '/tmp/RtmprzMcDg/pkg.2b822dec9ea8'
#> ✔ Creating 'R/'
#> ✔ Writing 'DESCRIPTION'
#> ✔ Writing 'NAMESPACE'
#> ✔ Setting active project to '<no active project>'

# Create function no visible global variables and missing documented functions
cat("
#' Function
#' @importFrom dplyr filter
#' @export
my_fun <- function() {
data %>%
filter(col == 3) %>%
mutate(new_col = 1) %>%
ggplot() +
  aes(x, y, colour = new_col) +
  geom_point()
}

#' Function not exported but with doc
my_not_exported_doc <- function() {
  message('Not exported but with title, should have @noRd')
}
", file = file.path(pkg_path, "R", "function.R"))

attachment::att_amend_desc(path = pkg_path)
#> Saving attachment parameters to yaml config file
#> Updating pkg.2b822dec9ea8 documentation
#> ℹ Loading pkg.2b822dec9ea8Writing ']8;;file:///tmp/RtmprzMcDg/pkg.2b822dec9ea8/NAMESPACENAMESPACE]8;;'Writing ']8;;file:///tmp/RtmprzMcDg/pkg.2b822dec9ea8/NAMESPACENAMESPACE]8;;'Writing ']8;;ide:run:pkgload::dev_help('my_fun')my_fun.Rd]8;;'Writing ']8;;ide:run:pkgload::dev_help('my_not_exported_doc')my_not_exported_doc.Rd]8;;'ℹ Loading pkg.2b822dec9ea8[+] 1 package(s) added: dplyr.

# Files of the package
fs::dir_tree(pkg_path, recurse = TRUE)
```

- Find missing `@return` and find missing `@noRd` for not exported
  function with documentation

``` r
find_missing_tags(pkg_path)
#> ℹ Loading pkg.2b822dec9ea8
#> Problem: Missing or empty return value for exported functions: my_fun
#> 
#> 
#> 
#> Problem: Doc available but need to choose between `@export` or `@noRd`: my_not_exported_doc
#> 
#> 
#> 
#> ℹ Loading pkg.2b822dec9ea8
#> $package_doc
#> # A tibble: 0 × 0
#> 
#> $data
#> # A tibble: 0 × 0
#> 
#> $functions
#> # A tibble: 2 × 11
#>      id filename   topic has_e…¹ has_r…² retur…³ has_n…⁴ rdnam…⁵ not_e…⁶ test_…⁷
#>   <int> <chr>      <chr> <lgl>   <lgl>   <chr>   <lgl>   <chr>   <lgl>   <chr>  
#> 1     1 function.R my_f… TRUE    FALSE   ""      FALSE   my_fun  FALSE   not_ok 
#> 2     2 function.R my_n… FALSE   FALSE   ""      FALSE   my_not… FALSE   ok     
#> # … with 1 more variable: test_has_export_or_has_nord <chr>, and abbreviated
#> #   variable names ¹​has_export, ²​has_return, ³​return_value, ⁴​has_nord,
#> #   ⁵​rdname_value, ⁶​not_empty_return_value, ⁷​test_has_export_and_return
```

- Get global variables

``` r
globals <- get_no_visible(pkg_path, quiet = TRUE)
globals
#> $globalVariables
#> # A tibble: 4 × 7
#>   notes                            filep…¹ fun   is_fu…² is_gl…³ varia…⁴ propo…⁵
#>   <chr>                            <chr>   <chr> <lgl>   <lgl>   <chr>   <chr>  
#> 1 my_fun: no visible binding for … -       my_f… FALSE   TRUE    data    " impo…
#> 2 my_fun: no visible binding for … -       my_f… FALSE   TRUE    x        <NA>  
#> 3 my_fun: no visible binding for … -       my_f… FALSE   TRUE    y        <NA>  
#> 4 my_fun: no visible binding for … -       my_f… FALSE   TRUE    new_col  <NA>  
#> # … with abbreviated variable names ¹​filepath, ²​is_function,
#> #   ³​is_global_variable, ⁴​variable, ⁵​proposed
#> 
#> $functions
#> # A tibble: 5 × 7
#>   notes                            filep…¹ fun   is_fu…² is_gl…³ varia…⁴ propo…⁵
#>   <chr>                            <chr>   <chr> <lgl>   <lgl>   <chr>   <chr>  
#> 1 my_fun: no visible global funct… -       my_f… TRUE    FALSE   %>%     <NA>   
#> 2 my_fun: no visible global funct… -       my_f… TRUE    FALSE   mutate  <NA>   
#> 3 my_fun: no visible global funct… -       my_f… TRUE    FALSE   ggplot  <NA>   
#> 4 my_fun: no visible global funct… -       my_f… TRUE    FALSE   aes     <NA>   
#> 5 my_fun: no visible global funct… -       my_f… TRUE    FALSE   geom_p… <NA>   
#> # … with abbreviated variable names ¹​filepath, ²​is_function,
#> #   ³​is_global_variable, ⁴​variable, ⁵​proposed
```

- Print globals to copy-paste

``` r
print_globals(globals)
#> --- Functions to add in NAMESPACE (with @importFrom ?) ---
#> 
#> my_fun: %>%, aes, geom_point, ggplot, mutate
#> 
#> --- Potential GlobalVariables ---
#> -- code to copy to your R/globals.R file --
#> 
#> globalVariables(unique(c(
#> # my_fun: 
#> "data", "new_col", "x", "y"
#> )))
```

- Store the output of `print_globals()` in package using
  `usethis::use_r("globals")`. Note that you can also transform all
  these variables with `.data[[variable]]`

### Experimental: Check that the user space is clean after checks

Have you faced a note on CRAN about non-standard things in the check
directory ?

    Check: for non-standard things in the check directory
    Result: NOTE
        Found the following files/directories:
         ‘extrapackage’ 

Maybe you do not understand where these files came from.  
Then, you can run `check_clean_userspace()` in your package directory to
detect every files that you created during the check.  
They could be issued from examples, tests or vignettes:
`check_clean_userspace()` will tell you.

``` r
check_clean_userspace()
```

    #> Package: checkpackage
    #> Title: What the Package Does (One Line, Title Case)
    #> Version: 0.0.0.9000
    #> Authors@R (parsed):
    #>     * First Last <first.last@example.com> [aut, cre] (YOUR-ORCID-ID)
    #> Description: What the package does (one paragraph).
    #> License: `use_mit_license()`, `use_gpl3_license()` or friends to pick a
    #>     license
    #> Encoding: UTF-8
    #> Roxygen: list(markdown = TRUE)
    #> RoxygenNote: 7.2.2
    #> ✔ | F W S  OK | Context
    #> ⠏ |         0 | in_test                                                         
    #> ══ Results ═════════════════════════════════════════════════════════════════════
    #> [ FAIL 0 | WARN 0 | SKIP 0 | PASS 0 ]
    #> 
    #> 🌈 Your tests are over the rainbow 🌈
    #> ── Running 4 example files ───────────────────────────────────── checkpackage ──
    #> 
    #> > text <- "in_example"
    #> 
    #> > file <- tempfile("in_example")
    #> 
    #> > cat(text, file = file)
    #> Warning in check_clean_userspace(pkg = path, check_output = check_output): One
    #> of the 'Run examples' .R file was created to run examples. You should not bother
    #> about it
    #> # A tibble: 5 × 4
    #>   source       problem where                                        file        
    #>   <chr>        <chr>   <chr>                                        <chr>       
    #> 1 Unit tests   added   /tmp/RtmprzMcDg/pkg-2b82ce31126/checkpackage /tmp/Rtmprz…
    #> 2 Unit tests   added   /tmp/RtmprzMcDg                              /tmp/Rtmprz…
    #> 3 Run examples added   /tmp/RtmprzMcDg                              /tmp/Rtmprz…
    #> 4 Run examples added   /tmp/RtmprzMcDg                              /tmp/Rtmprz…
    #> 5 Full check   added   /tmp/RtmprzMcDg                              /tmp/Rtmprz…

### Experimental: Check as CRAN with CRAN global variables

Use the exploration of CRAN scripts by the RConsortium to check a
package as CRAN does it with their env. variables. See
<https://github.com/RConsortium/r-repositories-wg/issues/17> for more
details.

``` r
# Check the current directory
check_as_cran()
```

## Code of Conduct

Please note that the checkhelper project is released with a [Contributor
Code of
Conduct](https://thinkr-open.github.io/checkhelper/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
