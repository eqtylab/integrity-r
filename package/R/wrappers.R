.integrity_is_asset <- function(value) {
  if (!inherits(value, "python.builtin.object")) {
    return(FALSE)
  }

  builtins <- reticulate::import("builtins", convert = FALSE)
  isTRUE(reticulate::py_to_r(builtins$isinstance(value, eqty$Asset)))
}

.integrity_asset_from_object <- function(
  value,
  asset_type,
  context,
  `_store`,
  name = NULL
) {
  args <- list(
    obj = value,
    asset_type = asset_type,
    ctx = context,
    `_store` = `_store`
  )
  if (!is.null(name) && nzchar(name)) {
    args$name <- name
  }

  do.call(eqty$Asset$`_from_object`, args)
}

.integrity_input_assets <- function(value, name, context, `_store`) {
  if (is.null(value)) {
    return(list())
  }

  if (.integrity_is_asset(value)) {
    return(list(value))
  }

  if (
    is.list(value) &&
    length(value) > 0L &&
    all(vapply(value, .integrity_is_asset, logical(1L)))
  ) {
    return(value)
  }

  if (
    inherits(value, "python.builtin.object") &&
    reticulate::py_has_attr(value, "to_eqty_asset")
  ) {
    return(list(value$to_eqty_asset()))
  }

  list(.integrity_asset_from_object(
    value,
    eqty$AssetType$CUSTOM,
    context,
    `_store`,
    name
  ))
}

.integrity_output_assets <- function(value, output_type, context, `_store`) {
  if (is.null(value)) {
    stop("The captured function must return a result", call. = FALSE)
  }

  if (.integrity_is_asset(value)) {
    return(value)
  }

  if (
    is.list(value) &&
    !inherits(value, "data.frame") &&
    length(value) > 0L
  ) {
    items <- value[!vapply(value, is.null, logical(1L))]
    return(lapply(items, function(item) {
      .integrity_output_assets(item, output_type, context, `_store`)
    }))
  }

  asset_type <- switch(
    tolower(output_type),
    dataset = eqty$AssetType$DATASET,
    model = eqty$AssetType$MODEL,
    eqty$AssetType$CUSTOM
  )
  .integrity_asset_from_object(value, asset_type, context, `_store`)
}

.integrity_asset_cids <- function(value) {
  if (.integrity_is_asset(value)) {
    return(list(value$cid))
  }

  if (is.list(value)) {
    return(unlist(lapply(value, .integrity_asset_cids), recursive = FALSE))
  }

  list()
}

.integrity_r_value <- function(value) {
  if (inherits(value, "python.builtin.object")) {
    return(reticulate::py_to_r(value))
  }

  if (is.list(value) && !inherits(value, "data.frame")) {
    return(lapply(value, .integrity_r_value))
  }

  value
}

.integrity_argument_names <- function(args, func) {
  argument_names <- names(args)
  if (is.null(argument_names)) {
    argument_names <- rep("", length(args))
  }

  formal_names <- setdiff(names(formals(func)), "...")
  available_names <- setdiff(formal_names, argument_names[nzchar(argument_names)])

  for (index in which(!nzchar(argument_names))) {
    if (length(available_names) == 0L) {
      break
    }
    argument_names[index] <- available_names[[1L]]
    available_names <- available_names[-1L]
  }

  argument_names
}

#' Wrap an R Function as a Computation
#'
#' Creates a callable computation from an R function. When the returned function
#' is called, the SDK records its inputs and outputs in the selected [Context].
#' The function executes directly in R. Its source is registered as a [Code]
#' asset, and each call creates a [Computation] that connects that code and the
#' call's inputs to its outputs. The computation can then serve as an entry point
#' when the context is exported as a manifest.
#'
#' @param context An optional [Context] created with `Context$new()` or a context
#'   factory. When omitted, the default context configured by [integrity_init()]
#'   is used.
#' @param metadata A named list of metadata for the computation, such as
#'   `list(name = "My algorithm", version = "1.0")`.
#'   The `name` value is also used as the display name of the recorded R code
#'   asset. If omitted, it defaults to `"R Function"`.
#' @param func The R function to wrap. When `NULL`, the result is a function that
#'   accepts the R function to wrap.
#' @param _store Whether to store the wrapped R function's source content in the
#'   local blob store. Defaults to `FALSE`. Set this to `TRUE` only when the
#'   source is safe to include and contains no secrets.
#'
#' @return A function that calls `func` and records the computation's inputs and
#'   produced outputs. Multiple outputs are returned as an ordinary R list. If
#'   `func` is `NULL`, returns a function that first accepts the function to
#'   wrap.
#'   
#' @examples
#' \dontrun{
#' ctx <- Context$new("Example computation")
#' 
#' # Define computation
#' my_algo <- integrity_compute(
#'   context = ctx,
#'   metadata = list(name = "Sum Generator"),
#'   func = function(x, y) {
#'      return(x + y)
#'   }
#' )
#' 
#' # Run it
#' result <- my_algo(10, 20)
#' }
#' @export
integrity_compute <- function(
  context = NULL,
  metadata = list(),
  func = NULL,
  `_store` = FALSE
) {
  if (is.null(func)) {
    return(function(f) {
      integrity_compute(
        context = context,
        metadata = metadata,
        func = f,
        `_store` = `_store`
      )
    })
  }

  r_source <- paste(deparse(func), collapse = "\n")

  fn_name <- metadata$name
  if (is.null(fn_name)) fn_name <- "R Function"

  fn_description <- metadata$description
  if (is.null(fn_description)) fn_description <- "R Algorithm Execution"

  code_factory <- if (is.null(context)) {
    eqty$Code
  } else {
    eqty$Code$with_context(context)
  }

  code_asset <- code_factory$from_object(
    r_source,
    name = fn_name,
    description = fn_description,
    language = "r",
    `_store` = `_store`
  )

  return(function(...) {
    call_args <- list(...)
    argument_names <- .integrity_argument_names(call_args, func)
    input_assets <- unlist(lapply(seq_along(call_args), function(index) {
      .integrity_input_assets(
        call_args[[index]],
        argument_names[[index]],
        context,
        `_store`
      )
    }), recursive = FALSE)

    execution_args <- lapply(call_args, .integrity_r_value)
    result <- do.call(func, execution_args)
    output_type <- metadata$output_type
    if (is.null(output_type)) {
      output_type <- "custom"
    }
    output_assets <- .integrity_output_assets(
      result,
      output_type,
      context,
      `_store`
    )

    computation_factory <- if (is.null(context)) {
      eqty$Computation
    } else {
      eqty$Computation$with_context(context)
    }
    computation <- do.call(computation_factory$new, metadata)
    computation$add_input_cid(code_asset$cid)

    for (input_asset in input_assets) {
      computation$add_input_cid(input_asset$cid)
    }
    for (output_cid in .integrity_asset_cids(output_assets)) {
      computation$add_output_cid(output_cid)
    }
    invisible(computation$finalize())

    output_assets
  })
}
