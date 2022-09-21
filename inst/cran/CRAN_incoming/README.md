Incoming checks are run each time there is a new packages send to CRAN

=> It seems that each member of CRAN runs a different set of test, depending on their OS

Scripts are:

- A Rscript that prepares the system and run the 'R CMD check" command: https://svn.r-project.org/R-dev-web/trunk/CRAN/QA/Kurt/lib/R/Scripts/check_CRAN_incoming.R
- It is amended with env. variables: https://svn.r-project.org/R-dev-web/trunk/CRAN/QA/Kurt/.R/check.Renviron

=> It seems that they do not use the --as-cran tag to run the check.
