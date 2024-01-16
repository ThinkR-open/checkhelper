path <- suppressWarnings(create_example_pkg())

test_that("find_missing_tags works", {

  # Check that the information transmitted by roxygen2 is correctly retransmitted by checkhelper

  if (packageVersion("roxygen2") >= "7.3.0") {
    # roxygen > 7.3.0 only generates messages
    out <- expect_message(
      find_missing_tags(path),
      "my_long_fun_name_for_multiple_lines_globals"
    )

    expect_message(
      find_missing_tags(path),
      "@return"
    )

  } else {
    # roxygen > 7.1.2 generates warnings and messages
    expect_warning(
      out <- expect_message(
        find_missing_tags(path),
        "my_long_fun_name_for_multiple_lines_globals"
      ),
      regexp = "@return"
    )
  }

  expect_type(out, "list")
  expect_length(out, 3)
  expect_equal(
    names(out),
    c("package_doc", "data", "functions")
  )

  functions <- out[["functions"]]

  expect_equal(nrow(functions), 5)
  expect_equal(functions$filename, rep("function.R", 5))
  expect_equal(
    functions$topic,
    c(
      "my_long_fun_name_for_multiple_lines_globals", "my_plot",
      "my_not_exported_doc", "my_not_exported_nord", "my_plot_rdname"
    )
  )
  expect_false("my_not_exported_nodoc" %in% functions$topic)
  expect_equal(functions$has_export, c(TRUE, TRUE, FALSE, FALSE, TRUE))
  # last is true because of rdname tag

    expect_equal(
      functions$has_return,
      c(FALSE, TRUE, FALSE, FALSE, TRUE)
    )

  expect_equal(
    functions$has_nord,
    c(FALSE, FALSE, FALSE, TRUE, FALSE)
  )

  expect_equal(
    functions$test_has_export_and_return,
    c("not_ok", "ok", "ok", "ok", "ok")
  )

  expect_equal(
    functions$test_has_export_or_has_nord,
    c("ok", "ok", "not_ok", "ok", "ok")
  )

  usethis::with_project(path, {
    usethis::use_package_doc()
    usethis::use_pipe()
    usethis::use_data(iris)
    use_data_doc("iris")

    cat(
      "
#' title
#' @param x x
#' @export
#' @return something
the_function <- function(x) x

#' @rdname the_function
#' @export
the_alias <- the_function

#' @rdname the_function
the_alias2 <- the_function

#' @rdname the_function
#' @noRd
the_alias3 <- the_function",
      file = "R/function.R",
      append = TRUE
    )

    cat(
      "


#' @rdname the_function
#' @export
the_other_alias <- the_function

#' @rdname the_function
the_other_alias2 <- the_function

#' @rdname the_function
#' @noRd
the_other_alias3 <- the_function",
      file = "R/function2.R"
    )

    if (packageVersion("roxygen2") >= "7.3.0") {
      # roxygen > 7.3.0 generates a message

      expect_message(attachment::att_amend_desc(),
                     regexp = "@return")
    } else {
      # roxygen > 7.1.2 generates a warning
      expect_warning(attachment::att_amend_desc(),
                     regexp = "@return")
    }

  })

  if (packageVersion("roxygen2") >= "7.3.0") {
    # roxygen > 7.3.0 only generates messages

    out <- expect_message(
      find_missing_tags(path),
      "my_long_fun_name_for_multiple_lines_globals"
    )

    expect_message(
      find_missing_tags(path),
      "@return"
    )

  } else {
    # roxygen > 7.1.2 generates warnings and messages

    expect_warning(
      out <- expect_message(
        find_missing_tags(path),
        "my_long_fun_name_for_multiple_lines_globals"
      ),
      regexp = "@return"
    )

  }

  expect_type(out, "list")
  expect_length(out, 3)
  expect_equal(
    names(out),
    c("package_doc", "data", "functions")
  )

  expect_equal(
    out[["package_doc"]],
    structure(
      list(
        filename = "checkpackage-package.R",
        has_keywords = TRUE
      ),
      class = c("tbl_df", "tbl", "data.frame"),
      row.names = c(NA, -1L)
    )
  )

  expect_equal(
    out[["data"]],
    structure(
      list(
        filename = "doc_iris.R",
        has_format = TRUE,
        has_title = TRUE,
        has_description = TRUE
      ),
      class = c("tbl_df", "tbl", "data.frame"),
      row.names = c(NA, -1L)
    )
  )

  expect_equal(
    out[["functions"]],
    structure(
      list(
        id = 1:12,
        filename = c(
          "function.R", "function.R",
          "function.R", "function.R", "function.R", "function.R", "function.R",
          "function.R", "function.R", "function2.R", "function2.R", "function2.R"
        ),
        topic = c(
          "my_long_fun_name_for_multiple_lines_globals", "my_plot",
          "my_not_exported_doc", "my_not_exported_nord", "my_plot_rdname",
          "the_function", "the_alias", "the_alias2", "the_alias3", "the_other_alias",
          "the_other_alias2", "the_other_alias3"
        ),
        has_export = c(
          TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE,
          FALSE, FALSE, TRUE, FALSE, FALSE
        ),
        has_return = c(
          FALSE, TRUE, FALSE, FALSE, TRUE, TRUE,
          TRUE, TRUE, TRUE, TRUE, TRUE, TRUE
        ),
        return_value = c(
          "", "GGplot for data", "", "", "GGplot for data",
          "something", "something", "something",
          "something", "something", "something", "something"
        ),
        has_nord = c(
          FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE,
          FALSE, TRUE, FALSE, FALSE, TRUE
        ),
        rdname_value = c(
          "my_long_fun_name_for_multiple_lines_globals",
          "my_plot", "my_not_exported_doc", "my_not_exported_nord", "my_plot",
          "the_function", "the_function", "the_function", "the_function",
          "the_function", "the_function", "the_function"
        ),
        not_empty_return_value = c(
          FALSE, TRUE, FALSE, FALSE, TRUE, TRUE,
          TRUE, TRUE, TRUE, TRUE, TRUE, TRUE
        ),
        test_has_export_and_return = c(
          "not_ok", "ok", "ok", "ok",
          "ok", "ok", "ok", "ok", "ok", "ok", "ok", "ok"
        ),
        test_has_export_or_has_nord = c(
          "ok",
          "ok", "not_ok", "ok", "ok", "ok", "ok", "not_ok", "ok", "ok",
          "not_ok", "ok"
        )
      ),
      row.names = c(NA, -12L),
      class = c("tbl_df", "tbl", "data.frame")
    )
  )
})

# Remove path
unlink(path, recursive = TRUE)
