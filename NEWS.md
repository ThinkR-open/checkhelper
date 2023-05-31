# checkhelper 0.1.0

## Major changes

- Check that there is no new file after tests, examples, vignettes of full check with `check_clean_userspace()` (#13)

## Minor changes

- Clean userspace after examples and tests
- Export `create_example_pkg()` to get examples in functions documentation

## Bring the package up to standard (#25)

- Modify the LICENCE to MIT
- Update Code Of Conduct to a recent version
- Add a package documentation
- Update Github Actions workflows

# checkhelper 0.0.1

- Check with same variables and parameters as CRAN with `check_as_cran()` (#21)
- Find missing tags in your roxygen skeletons with `find_missing_tags()`
- Print code to add to 'globals.R' with `print_globals()`
- Extract "no visibles" from notes of `rcmdcheck()`
- Added a `NEWS.md` file to track changes to the package.
