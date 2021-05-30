#' Find missing 'return' tag when function exported
#'
#' @inheritParams roxygen2::roxygenise
#'
#' @return Tibble of all functions with information whether documentation is correct or not
#' @importFrom utils getFromNamespace
#' @export
#'
#' @examples
#' \dontrun{
#' find_missing_values()
#' }
find_missing_values <- function (package.dir = ".", roclets = NULL, load_code = NULL,
                                 clean = FALSE)
{
  # browser()
  base_path <- normalizePath(package.dir, mustWork = TRUE)
  # is_first <- roxygen2:::roxygen_setup(base_path)
  is_first <- getFromNamespace("roxygen_setup", "roxygen2")(base_path)
  encoding <- desc::desc_get("Encoding", file = base_path)[[1]]
  if (!identical(encoding, "UTF-8")) {
    warning("roxygen2 requires Encoding: UTF-8", call. = FALSE)
  }
  # roxygen2:::roxy_meta_load(base_path)
  getFromNamespace("roxy_meta_load", "roxygen2")(base_path)
  packages <- roxygen2::roxy_meta_get("packages")
  lapply(packages, loadNamespace)
  # roclets <- roxygen2:::`%||%`(roclets, roxy_meta_get("roclets"))
  roclets <- getFromNamespace("%||%", "roxygen2")(roclets, roxygen2::roxy_meta_get("roclets"))
  if ("collate" %in% roclets) {
    roxygen2::update_collate(base_path)
    roclets <- setdiff(roclets, "collate")
  }
  if (length(roclets) == 0)
    return(invisible())
  roclets <- lapply(roclets, roxygen2::roclet_find)
  # load_code <- roxygen2:::find_load_strategy(load_code)
  load_code <- getFromNamespace("find_load_strategy", "roxygen2")(load_code)
  env <- load_code(base_path)
  # roxygen2:::roxy_meta_set("env", env)
  getFromNamespace("roxy_meta_set", "roxygen2")("env", env)
  # on.exit(roxygen2:::roxy_meta_set("env", NULL), add = TRUE)
  on.exit(getFromNamespace("roxy_meta_set", "roxygen2")("env", NULL), add = TRUE)
  # blocks <- roxygen2:::parse_package(base_path, env = NULL)
  blocks <- getFromNamespace("parse_package", "roxygen2")(base_path, env = NULL)
  if (clean) {
    # purrr::walk(roclets, roxygen2:::roclet_clean, base_path = base_path)
    purrr::walk(roclets, getFromNamespace("roclet_clean", "roxygen2"), base_path = base_path)
  }
  # roclets <- lapply(roclets, roxygen2:::roclet_preprocess, blocks = blocks,
  roclets <- lapply(roclets, getFromNamespace("roclet_preprocess", "roxygen2"), blocks = blocks,
                    base_path = base_path)
  # blocks <- lapply(blocks, roxygen2:::block_set_env, env = env)
  blocks <- lapply(blocks, getFromNamespace("block_set_env", "roxygen2"), env = env)

  res_topic <- lapply(blocks, function(x) {
    topic <- x$object$topic
    if (is.null(topic)) {""} else {topic}
  })
  res_find_export <- lapply(blocks, roxygen2::block_has_tags, tags = list("export"))
  res_find_return <- lapply(blocks, roxygen2::block_has_tags, tags = list("return"))
  res_find_return_value <- lapply(blocks, function(x) {
    return <- roxygen2::block_get_tag_value(x, tag = "return")
    if (is.null(return)) {""} else {return}
  })

  res <- dplyr::tibble(
    topic = unlist(res_topic),
    has_export = unlist(res_find_export),
    has_return = unlist(res_find_return),
    return_value = unlist(res_find_return_value),
    not_empty_return_value = (return_value != ""),
    has_export_and_return_ok = (has_export & has_return & not_empty_return_value) | !has_export,
)

  res_missing <- res[!res$has_export_and_return_ok,]
  message("Missing or empty return value for functions: ", paste(res_missing$topic, collapse = ", "))


  return(res)
  # results <- lapply(roclets, roxygen2:::roclet_process, blocks = blocks,
  #                   env = env, base_path = base_path)
  # out <- purrr::map2(roclets, results, roxygen2:::roclet_output, base_path = base_path,
  #                    is_first = is_first)
  # invisible(out)
}
