#' Create a Python Dictionary for SDK Calls
#'
#' Converts named R values to a Python `dict` for SDK methods that expect one.
#'
#' @param ... Named values and optional arguments passed to [reticulate::dict()].
#' @return A Python `dict` object.
#' @export
integrity_dict <- function(...) {
  reticulate::dict(...)
}

#' Create a Python Path for SDK Calls
#'
#' Converts an R path value to Python's `pathlib.Path`, as required by methods
#' such as `Context$export()` and `Context$import_manifest()`.
#'
#' @param path A character string or path-like value.
#' @return A Python `pathlib.Path` object.
#' @export
integrity_path <- function(path) {
  reticulate::import("pathlib", convert = FALSE)$Path(path)
}

#' Resolve a Path from an SDK Value
#'
#' Extracts a character path from an SDK asset, a Python path object, or a
#' character value. If no direct path is available, the helper also checks the
#' object's value.
#'
#' @param input_object An SDK asset, Python path object, or character value.
#' 
#' @return A character string containing the resolved path. Returns `NULL` if no path 
#'   could be determined.
#' 
#' @export
integrity_resolve_path <- function(input_object) {
  data_path <- NULL

  try_path <- tryCatch({
    as.character(input_object$path)
  }, error = function(e) NULL)

  if (!is.null(try_path)) {
    data_path <- try_path
  } else {
    try_str <- tryCatch({
      as.character(input_object)
    }, error = function(e) NULL)

    if (!is.null(try_str)) {
      data_path <- try_str
    }
  }

  if (is.null(data_path)) {
    try_value <- tryCatch({
      as.character(input_object$value)
    }, error = function(e) NULL)
    if (!is.null(try_value)) {
      data_path <- try_value
    }
  }

  return(data_path)
}
