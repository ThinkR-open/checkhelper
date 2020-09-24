
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![R build
status](https://github.com/ThinkR-open/checkhelper/workflows/R-CMD-check/badge.svg)](https://github.com/ThinkR-open/checkhelper/actions)
[![Codecov test
coverage](https://codecov.io/gh/ThinkR-open/checkhelper/branch/master/graph/badge.svg)](https://codecov.io/gh/ThinkR-open/checkhelper?branch=master)
<!-- badges: end -->

# checkhelper

A package to help you deal with `devtools::check()` outputs

Complete documentation in the {pkgdown} site:
<https://thinkr-open.github.io/checkhelper/>

## Installation

You can install the last version of checkhelper from github with:

``` r
remotes::install_github("thinkr-open/checkhelper")
```

## Examples

Check your current package under development and get all the globals
missing: `no visible global variable` and `no visible global function`

### Directly in your package in development

  - You can directly use `checkhelper::print_globals()` on your package
    instead of `devtools::check()`. This is a wrapper around
    `rcmdcheck::rcmdcheck()`. This will run the checks and directly list
    the potential “globalVariables” to add in a `globals.R` file.

<!-- end list -->

``` r
checkhelper::print_globals(quiet = TRUE)
#> There is no globalVariable detected.
```

### Reproducible example

  - Create a fake package with a function having globalvariables

<!-- end list -->

``` r
library(checkhelper)

# Create fake package ----
tempdir <- tempdir()
# Create fake package
usethis::create_package(file.path(tempdir, "checkpackage"), open = FALSE)
#> ✓ Creating '/tmp/Rtmpm7UmMb/checkpackage/'
#> ✓ Setting active project to '/tmp/Rtmpm7UmMb/checkpackage'
#> ✓ Creating 'R/'
#> ✓ Writing 'DESCRIPTION'
#> ✓ Writing 'NAMESPACE'
#> ✓ Setting active project to '<no active project>'

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
", file = file.path(tempdir, "checkpackage", "R", "function.R"))

path <- file.path(tempdir, "checkpackage")
# run roxygen and fill the DESCRIPTION with dependencies
attachment::att_to_description(path = path)
#> Updating checkpackage documentation
#> Loading checkpackage
#> [+] 1 package(s) added: dplyr.
```

  - Get global variables

<!-- end list -->

``` r
globals <- get_no_visible(path, quiet = TRUE)
globals
#> $globalVariables
#> # A tibble: 4 x 6
#>   notes              fun    is_function is_global_varia… variable proposed      
#>   <chr>              <chr>  <lgl>       <lgl>            <chr>    <chr>         
#> 1 my_fun: no visibl… my_fun FALSE       TRUE             data     "  importFrom…
#> 2 my_fun: no visibl… my_fun FALSE       TRUE             x         <NA>         
#> 3 my_fun: no visibl… my_fun FALSE       TRUE             y         <NA>         
#> 4 my_fun: no visibl… my_fun FALSE       TRUE             new_col   <NA>         
#> 
#> $functions
#> # A tibble: 5 x 6
#>   notes                    fun    is_function is_global_varia… variable proposed
#>   <chr>                    <chr>  <lgl>       <lgl>            <chr>    <chr>   
#> 1 my_fun: no visible glob… my_fun TRUE        FALSE            %>%      <NA>    
#> 2 my_fun: no visible glob… my_fun TRUE        FALSE            mutate   <NA>    
#> 3 my_fun: no visible glob… my_fun TRUE        FALSE            ggplot   <NA>    
#> 4 my_fun: no visible glob… my_fun TRUE        FALSE            aes      <NA>    
#> 5 my_fun: no visible glob… my_fun TRUE        FALSE            geom_po… <NA>
```

  - Print globals to copy-paste

<!-- end list -->

``` r
print_globals(globals)
#> --- Fonctions to add in NAMESPACE (with @importFrom ?) ---
#> 
#> my_fun: %>%, aes, geom_point, ggplot, mutate
#> 
#> --- Potential GlobalVariables ---
#> -- code to copy to your globals.R file --
#> 
#> globalVariables(c(unique(
#> # my_fun: 
#> "data", "new_col", "x", "y"
#> )))
```

  - Store in package using `usethis::use_r("globals")`
    
    Please note that this project is released with a [Contributor Code
    of Conduct](CODE_OF_CONDUCT.md). By participating in this project
    you agree to abide by its terms.
