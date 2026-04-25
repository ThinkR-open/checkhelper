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

  ## Topic-only blocks: documenting NULL with @name / @rdname (#82). They
  ## carry the @return for a family but the previous logic ignored them
  ## because the object class is not "function".
  res_topic_only <- map(
    .x = blocks,
    .f = ~ if (!class(.x[["object"]])[1] %in% c("function", "package", "data")) .x
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
  # @return and @returns are aliases (#81). Also count an explicit
  # @inherit X return as providing a return tag (#84).
  res_find_return <- lapply(res_functions, function(b) {
    block_has_return_tag(b)
  })
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
    block_get_return_value(x)
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


  # Pre-coerce so empty packages produce a 0-row tibble with the right
  # columns (#18). Without this, unlist(list()) returns NULL and tibble()
  # silently drops the column, making downstream mutate() fail.
  res <- tibble(
    filename = as.character(unlist(res_find_filename)),
    topic = as.character(unlist(res_topic)),
    has_export = as.logical(unlist(res_find_export)),
    has_return = as.logical(unlist(res_find_return)),
    return_value = as.character(unlist(res_find_return_value)),
    has_nord = as.logical(unlist(res_find_nord)),
    rdname_value = as.character(unlist(res_find_rdname_value))
  ) %>%
    mutate(
      rdname_value = if_else(rdname_value == "", topic, rdname_value),
      id = if (n() == 0L) integer() else seq_len(n())
    )

  # Pull `@return` values from topic-only blocks (`#' @name foo \n NULL`) so
  # aliases that resolve to them via `@rdname` are not flagged as missing
  # (#82). Topic blocks themselves are not surfaced in the final output —
  # they only feed the alias propagation below.
  topic_returns <- topic_block_returns(res_topic_only)
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
    apply_topic_block_returns(topic_returns) %>%
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

#' Does the block carry a return tag?
#'
#' Treats `@return`, `@returns` (alias added in roxygen2 7.2+, see issue #81)
#' and `@inherit X return` (see issue #84) as equivalent.
#'
#' @param block A roxygen2 block.
#' @return TRUE if any of those forms is present.
#' @noRd
block_has_return_tag <- function(block) {
  hits <- roxygen2::block_has_tags(block, tags = list("return", "returns"))
  if (any(hits)) {
    return(TRUE)
  }
  inherit <- roxygen2::block_get_tag_value(block, tag = "inherit")
  if (is.null(inherit)) {
    return(FALSE)
  }
  fields <- inherit$fields
  if (is.null(fields)) {
    # roxygen2 default: when @inherit X is given without explicit fields,
    # everything is inherited (description, details, return, ...)
    return(TRUE)
  }
  any(c("return", "returns") %in% fields)
}

#' Pull the literal return / returns text from a block, "" if none.
#'
#' For inherited returns we substitute the @inherit source so the value is
#' non-empty (the actual rendered text would come from the source).
#'
#' @param block A roxygen2 block.
#' @return character(1).
#' @noRd
block_get_return_value <- function(block) {
  for (tag in c("return", "returns")) {
    val <- roxygen2::block_get_tag_value(block, tag = tag)
    if (!is.null(val) && nzchar(as.character(val))) {
      return(as.character(val))
    }
  }
  inherit <- roxygen2::block_get_tag_value(block, tag = "inherit")
  if (!is.null(inherit)) {
    fields <- inherit$fields
    if (is.null(fields) ||
        any(c("return", "returns") %in% fields)) {
      return(paste0("@inherit ", inherit$source))
    }
  }
  ""
}

#' Build a (rdname -> return_value) lookup from topic-only blocks (#82).
#'
#' A topic block is a roxygen2 block that documents `NULL` (i.e. it has a
#' name/rdname tag but no associated function/data/package object). Its
#' `@return` is meant to apply to every function aliased onto it via
#' `@rdname`.
#'
#' @param topic_blocks list of roxygen2 blocks with non-function objects.
#' @return named character vector: names are rdnames, values are return text.
#' @noRd
topic_block_returns <- function(topic_blocks) {
  out <- character()
  for (b in topic_blocks) {
    val <- block_get_return_value(b)
    if (!nzchar(val)) next
    rdname <- roxygen2::block_get_tag_value(b, tag = "rdname")
    if (is.null(rdname) || !nzchar(rdname)) {
      rdname <- b[["object"]][["topic"]]
    }
    if (is.null(rdname) || !nzchar(rdname)) {
      rdname <- roxygen2::block_get_tag_value(b, tag = "name")
    }
    if (is.null(rdname) || !nzchar(rdname)) next
    out[[rdname]] <- val
  }
  out
}

#' Patch the joined results with returns inherited from topic-only blocks (#82).
#'
#' Aliases with `@rdname X` whose canonical doc is `NULL` (a topic block)
#' should not be reported as missing a return tag.
#'
#' @param res joined tibble produced by [set_correct_return_to_alias()].
#' @param topic_returns named character vector from [topic_block_returns()].
#' @return updated tibble.
#' @noRd
apply_topic_block_returns <- function(res, topic_returns) {
  if (length(topic_returns) == 0L) {
    return(res)
  }
  hit <- res$rdname_value %in% names(topic_returns)
  if (!any(hit)) {
    return(res)
  }
  res$has_return[hit] <- TRUE
  empty <- hit & !nzchar(res$return_value)
  res$return_value[empty] <- unname(topic_returns[res$rdname_value[empty]])
  res$not_empty_return_value[hit] <- TRUE
  res
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
