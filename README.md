
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![R build
status](https://github.com/ThinkR-open/checkhelper/workflows/R-CMD-check/badge.svg)](https://github.com/ThinkR-open/checkhelper/actions)
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

``` r
# Get globals
globals <- get_no_visible()
globals
```

    #> $globalVariables
    #> # A tibble: 4 x 6
    #>   notes           fun   is_function is_global_varia… variable proposed     
    #>   <chr>           <chr> <lgl>       <lgl>            <chr>    <chr>        
    #> 1 my_fun: no vis… my_f… FALSE       TRUE             data     "  importFro…
    #> 2 my_fun: no vis… my_f… FALSE       TRUE             x        <NA>         
    #> 3 my_fun: no vis… my_f… FALSE       TRUE             y        <NA>         
    #> 4 my_fun: no vis… my_f… FALSE       TRUE             new_col  <NA>         
    #> 
    #> $functions
    #> # A tibble: 5 x 6
    #>   notes               fun    is_function is_global_varia… variable proposed
    #>   <chr>               <chr>  <lgl>       <lgl>            <chr>    <chr>   
    #> 1 my_fun: no visible… my_fun TRUE        FALSE            %>%      <NA>    
    #> 2 my_fun: no visible… my_fun TRUE        FALSE            mutate   <NA>    
    #> 3 my_fun: no visible… my_fun TRUE        FALSE            ggplot   <NA>    
    #> 4 my_fun: no visible… my_fun TRUE        FALSE            aes      <NA>    
    #> 5 my_fun: no visible… my_fun TRUE        FALSE            geom_po… <NA>

``` r
# Print globals to copy-paste
print_globals(globals)
# Store in package using usethis::use_r("globals")
```

    #> --- Fonctions to add in NAMESPACE ---
    #> 
    #> %>%, aes, geom_point, ggplot, mutate
    #> 
    #> --- Potential GlobalVariables ---
    #> 
    #> globalVariables(
    #> c(
    #> "data", "x", "y", "new_col"
    #> )
    #> )
    # Store in package using usethis::use_r("globals")

Please note that this project is released with a [Contributor Code of
Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree
to abide by its terms.
