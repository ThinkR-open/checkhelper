#' Find missing 'return' tag when function exported
#'
#' @inheritParams roxygen2::roxygenise
#'
#' @return a list with the 3 data.frames with the missing tags
#' @importFrom utils getFromNamespace
#' @importFrom dplyr mutate filter left_join if_else tibble
#' @importFrom dplyr group_by summarise first select n
#' @importFrom purrr walk map keep compact
#' @export
#'
#' @examples
#' \dontrun{
#' # What you will do from inside your package
#' find_missing_tags()
#' }
#' # A reproducible example on a test package
#' pkg_path <- create_example_pkg()
#' find_missing_tags(pkg_path)
find_missing_tags <- function(package.dir = ".",
                              roclets = NULL,
                              load_code = NULL,
                              clean = FALSE) {
  base_path <- normalizePath(package.dir, mustWork = TRUE)

  encoding <- desc::desc_get("Encoding", file = base_path)[[1]]

  if (!identical(encoding, "UTF-8")) {
    warning("roxygen2 requires Encoding: UTF-8", call. = FALSE)
  }

  getFromNamespace("roxy_meta_load", "roxygen2")(base_path)

  packages <- roxygen2::roxy_meta_get("packages")

  lapply(packages, loadNamespace)

  roclets <- getFromNamespace("%||%", "roxygen2")(roclets, roxygen2::roxy_meta_get("roclets"))

  if ("collate" %in% roclets) {
    roxygen2::update_collate(base_path)
    roclets <- setdiff(roclets, "collate")
  }

  if (length(roclets) == 0) {
    return(invisible())
  }

  roclets <- lapply(roclets, roxygen2::roclet_find)

  load_code <- getFromNamespace("find_load_strategy", "roxygen2")(load_code)

  env <- load_code(base_path)

  getFromNamespace("roxy_meta_set", "roxygen2")("env", env)

  on.exit(getFromNamespace("roxy_meta_set", "roxygen2")("env", NULL),
    add = TRUE
  )

  blocks <- getFromNamespace("parse_package", "roxygen2")(base_path, env = NULL)

  if (clean) {
    walk(
      roclets,
      getFromNamespace("roclet_clean", "roxygen2"),
      base_path = base_path
    )
  }

  roclets <- lapply(
    roclets,
    getFromNamespace("roclet_preprocess", "roxygen2"),
    blocks = blocks,
    base_path = base_path
  )

  blocks <- lapply(
    blocks,
    getFromNamespace("block_set_env", "roxygen2"),
    env = env
  )

  ##
  ## Split blocks into functions or documentations
  ##
  res_functions <- map(
    .x = blocks,
    .f = ~ if (class(.x[["object"]])[1] == "function") .x
  ) %>%
    compact()

  res_package <- map(
    .x = blocks,
    .f = ~ if (class(.x[["object"]])[1] == "package") .x
  ) %>%
    compact()

  res_data <- map(
    .x = blocks,
    .f = ~ if (class(.x[["object"]])[1] == "data") .x
  ) %>%
    compact()


  ## Check for missing tags

  ### Package documentation
  ###
  res_package_filename <- lapply(res_package, function(x) basename(x[["file"]]))
  res_package_keywords <- purrr::map(res_package, roxygen2::block_has_tags, tags = list("keywords"))

  ### Data documentation
  ###
  res_data_filename <- lapply(res_data, function(x) basename(x[["file"]]))
  res_data_format <- map(res_data, roxygen2::block_has_tags, tags = list("format"))
  res_data_title <- map(res_data, roxygen2::block_has_tags, tags = list("title"))
  res_data_description <- map(res_data, roxygen2::block_has_tags, tags = list("description"))


  res_topic <- lapply(res_functions, function(x) {
    topic <- x[["object"]][["topic"]]
    if (is.null(topic)) {
      ""
    } else {
      topic
    }
  })

  res_find_filename <- lapply(res_functions, function(x) basename(x[["file"]]))

  res_find_export <- lapply(res_functions, roxygen2::block_has_tags, tags = list("export"))
  res_find_return <- lapply(res_functions, roxygen2::block_has_tags, tags = list("return"))
  res_find_nord <- lapply(res_functions, roxygen2::block_has_tags, tags = list("noRd"))

  res_find_rdname_value <- lapply(res_functions, function(x) {
    rdname <- roxygen2::block_get_tag_value(x, tag = "rdname")
    if (is.null(rdname)) {
      ""
    } else {
      rdname
    }
  })
  res_find_return_value <- lapply(res_functions, function(x) {
    return <- roxygen2::block_get_tag_value(x, tag = "return")
    if (is.null(return)) {
      ""
    } else {
      return
    }
  })

  res_package_doc <- tibble(
    filename = unlist(res_package_filename),
    has_keywords = unlist(res_package_keywords)
  )

  res_package_data <- tibble(
    filename = unlist(res_data_filename),
    has_format = unlist(res_data_format),
    has_title = unlist(res_data_title),
    has_description = unlist(res_data_description)
  )


  res <- tibble(
    filename = unlist(res_find_filename),
    topic = unlist(res_topic),
    has_export = unlist(res_find_export),
    has_return = unlist(res_find_return),
    return_value = unlist(res_find_return_value),
    has_nord = unlist(res_find_nord),
    rdname_value = unlist(res_find_rdname_value)
  ) %>%
    mutate(
      rdname_value = if_else(rdname_value == "", topic, rdname_value),
      id = 1:n()
    )
  # Join with itself to find common rdname
  res_join <- res %>%
    select(filename, id, topic, rdname_value) %>%
    left_join(
      res %>% filter(rdname_value != "") %>% select(-rdname_value, -id),
      by = c("filename", "topic")
    ) %>%
    group_by(id, filename, topic) %>%
    summarise(
      has_export = any(has_export),
      has_return = any(has_return),
      return_value = ifelse(any(return_value != ""), first(return_value[return_value != ""]), ""),
      has_nord = any(has_nord),
      rdname_value = first(rdname_value),
      .groups = "drop"
    ) %>%
    mutate(
      not_empty_return_value = (return_value != "")
    ) %>%
    set_correct_return_to_alias() %>%
    mutate(
      test_has_export_and_return = ifelse((has_export & has_return & not_empty_return_value) | !has_export,
        "ok", "not_ok"
      ),
      test_has_export_or_has_nord = ifelse((!has_export & has_nord) | has_export, "ok", "not_ok")
    )

  res_return_error <- res_join[res_join$test_has_export_and_return == "not_ok", ]
  if (nrow(res_return_error) != 0) {
    message("Problem: Missing or empty return value for exported functions: ", paste(res_return_error$topic, collapse = ", "), "\n\n")
  } else {
    message("Good! There is no missing or empty return value for exported functions")
  }
  res_export_error <- res_join[res_join$test_has_export_or_has_nord == "not_ok", ]
  if (nrow(res_export_error) != 0) {
    message("Problem: Doc available but need to choose between `@export` or `@noRd`: ", paste(res_export_error$topic, collapse = ", "), "\n\n")
  } else {
    message("Good! There is no missing `@export` or `@noRd` in your documentation")
  }

  # Set NAMESPACE back to normal
  roxygen2::roxygenise(package.dir = package.dir)

  final_res <- list(
    package_doc = res_package_doc,
    data = res_package_data,
    functions = res_join
  )

  return(final_res)
}

#' This is an internal function
#' When an alias is used with `@rdname`,
#' the alias should have the same return value as the original function.
#'
#' @importFrom dplyr group_by mutate first ungroup
#'
#' @noRd
set_correct_return_to_alias <- function(res) {
  res %>%
    group_by(rdname_value) %>%
    mutate(
      has_return = any(has_return),
      not_empty_return_value = any(not_empty_return_value),
      return_value = ifelse(
        any(return_value != ""),
        first(return_value[return_value != ""]),
        ""
      ),
    ) %>%
    ungroup()
}
