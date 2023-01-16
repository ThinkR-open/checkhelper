
<!-- README.md is generated from README.Rmd. Please edit that file -->
<!-- badges: start -->

[![R-CMD-check](https://github.com/ThinkR-open/checkhelper/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ThinkR-open/checkhelper/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/ThinkR-open/checkhelper/branch/master/graph/badge.svg)](https://codecov.io/gh/ThinkR-open/checkhelper?branch=master)
<!-- badges: end -->

# checkhelper

A package to help you deal with `devtools::check()` outputs and helps
avoids problems with CRAN submissions

Complete documentation in the {pkgdown} site:
<https://thinkr-open.github.io/checkhelper/>

## Installation

You can install the last version of checkhelper from r-universe with:

``` r
install.packages('checkhelper', repos = 'https://thinkr-open.r-universe.dev')
```

Or from GitHub:

``` r
remotes::install_github("thinkr-open/checkhelper")
```

## Examples

-   Check your current package under development and get all the globals
    missing: `no visible global variable` and
    `no visible global function`
-   Detect exported functions with missing or empty `@return` / `@noRd`
    tags

### Directly in your package in development

-   Use `checkhelper::find_missing_tags()` on your package in
    development to find which functions are exported but missing
    `@export` roxygen2 tag.
    -   CRAN policy asks for every exported function to have a value
        (named `@export` when using {roxygen2}).
    -   This also checks that not exported functions dont have roxygen
        title, or have `@noRd` in case you faced
        `Please add \value to .Rd files` CRAN message for documented but
        not exported functions.
-   You can directly use `checkhelper::print_globals()` on your package
    instead of `devtools::check()`. This is a wrapper around
    `rcmdcheck::rcmdcheck()`. This will run the checks and directly list
    the potential “globalVariables” to add in a `globals.R` file.

``` r
checkhelper::find_missing_tags()

checkhelper::print_globals(quiet = TRUE)
```

### Reproducible example with a fake package in tempdir

-   Create a fake package with
    -   a function having global variables
    -   a function with `@export` but no `@return`
    -   a function with title but without `@export` and thus missing
        `@noRd`

``` r
library(checkhelper)

# Create fake package ----
pkg_path <- tempfile(pattern = "pkg.")
dir.create(pkg_path)

# Create fake package
usethis::create_package(pkg_path, open = FALSE)
#> ✔ Setting active project to '/private/var/folders/_b/3msvt4xs27jgygz7xykllstw0000gn/T/Rtmp1Hf0yE/pkg.4c1d46124bd3'
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
#> Updating pkg.4c1d46124bd3 documentation
#> ℹ Loading pkg.4c1d46124bd3Writing 'NAMESPACE'Writing 'NAMESPACE'Writing 'my_fun.Rd'Writing 'my_not_exported_doc.Rd'ℹ Loading pkg.4c1d46124bd3[+] 1 package(s) added: dplyr.

# Files of the package
fs::dir_tree(pkg_path, recurse = TRUE)
```

-   Find missing `@return` and find missing `@noRd` for not exported
    function with documentation

``` r
find_missing_tags(pkg_path)
#> ℹ Loading pkg.4c1d46124bd3
#> Missing or empty return value for exported functions: my_fun
#> 
#> 
#> 
#> Doc available but need to choose between `@export` or `@noRd`: my_not_exported_doc
#> 
#> 
#> 
#> ℹ Loading pkg.4c1d46124bd3
#> # A tibble: 2 × 11
#>      id filename   topic has_e…¹ has_r…² retur…³ has_n…⁴ rdnam…⁵ not_e…⁶ test_…⁷
#>   <int> <chr>      <chr> <lgl>   <lgl>   <chr>   <lgl>   <chr>   <lgl>   <chr>  
#> 1     1 function.R my_f… TRUE    FALSE   ""      FALSE   my_fun  FALSE   not_ok 
#> 2     2 function.R my_n… FALSE   FALSE   ""      FALSE   my_not… FALSE   ok     
#> # … with 1 more variable: test_has_export_or_has_nord <chr>, and abbreviated
#> #   variable names ¹​has_export, ²​has_return, ³​return_value, ⁴​has_nord,
#> #   ⁵​rdname_value, ⁶​not_empty_return_value, ⁷​test_has_export_and_return
```

-   Get global variables

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

-   Print globals to copy-paste

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

-   Store the output of `print_globals()` in package using
    `usethis::use_r("globals")`. Note that you can also transform all
    these variables with `.data[[variable]]`

### Experimental: Check as CRAN with CRAN global variables

Use the exploration of CRAN scripts by the RConsortium to check a
package as CRAN does it with their env. variables. See
<https://github.com/RConsortium/r-repositories-wg/issues/17> for more
details.

``` r
check_dir <- tempfile("example")
# Check the current directory
check_as_cran(check_dir = check_dir)
# Open directory with all outputs
utils::browseURL(check_dir)
```

## Code of Conduct

Please note that the checkhelper project is released with a [Contributor
Code of
Conduct](https://thinkr-open.github.io/checkhelper/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
