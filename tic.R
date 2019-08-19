get_stage("install") %>%
  add_step(step_install_github("ThinkR-open/thinkrtemplate"))

do_package_checks()

if (ci_on_travis()) {
  do_pkgdown()
}

get_stage("deploy") %>%
  add_step(step_build_pkgdown()) %>%
  add_step(step_push_deploy(branch = "gh-pages", path = "docs"))
