# the goal of this file is to have a trace of all devtools/usethis
# call you make for yout project

usethis::use_build_ignore("devstuff_history.R")
usethis::create_package(".")
available::available("checkhelper")

usethis::use_readme_rmd()
usethis::use_news_md()
usethis::use_code_of_conduct()

# description ----
library(desc)
unlink("DESCRIPTION")
my_desc <- description$new("!new")
my_desc$set_version("0.0.0.9000")
my_desc$set(Package = "checkhelper")
my_desc$set(Title = "Deal with check outputs")
my_desc$set(Description = "A package to help you deal with devtools::check outputs.")
my_desc$set("Authors@R",
            'c(
            person("Sebastien", "Rochette", email = "sebastien@thinkr.fr", role = c("aut", "cre")),
            person("Vincent", "Guyader", email = "vincent@thinkr.fr", role = c("aut")))')
my_desc$set("URL", "https://github.com/ThinkR-open/checkhelper")
my_desc$set("BugReports", "https://github.com/ThinkR-open/checkhelper/issues")
my_desc$set("VignetteBuilder", "knitr")
my_desc$del("Maintainer")
my_desc$write(file = "DESCRIPTION")

# Others ----
usethis::use_roxygen_md()
usethis::use_pipe()
options(usethis.full_name = "Sébastien Rochette")
usethis::use_gpl3_license()
usethis::use_test("checkhelper")

# CI ----
chameleon::build_pkgdown(
  lazy = TRUE,
  yml = system.file("pkgdown/_pkgdown.yml", package = "thinkridentity"),
  favicon = system.file("pkgdown/favicon.ico", package = "thinkridentity"),
  move = FALSE, clean_before = TRUE
)
# tic::use_tic()
travis::travis_set_pat()
# usethis::use_coverage()
# usethis::use_appveyor()
usethis::use_github_action_check_standard()
usethis::use_github_action("pkgdown")
usethis::use_github_action("test-coverage")

# PR ----
usethis::pr_fetch(10)
usethis::pr_push()

# Development ----
attachment::att_to_description() #dir.v = ""
checkhelper::print_globals()
usethis::use_r("globals")

# Documentation ----
usethis::use_vignette("deal-with-check-outputs")


devtools::build_vignettes()
devtools::load_all()
rcmdcheck::rcmdcheck()

