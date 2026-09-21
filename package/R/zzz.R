.integrity_proxy <- function(name = NULL) {
  structure(list(name = name), class = "eqty_sdk_proxy")
}

# Keep exported SDK objects inert until a user accesses one of their members.
# Package checks inspect exported objects, so active bindings here would
# initialize Python during otherwise static checks.
`$.eqty_sdk_proxy` <- function(x, name) {
  target <- .integrity_sdk()
  proxy_name <- unclass(x)[["name"]]
  if (!is.null(proxy_name)) {
    target <- reticulate::py_get_attr(target, proxy_name)
  }
  reticulate::py_get_attr(target, name)
}

eqty <- .integrity_proxy()

Agent <- .integrity_proxy("Agent")
Asset <- .integrity_proxy("Asset")
AssetType <- .integrity_proxy("AssetType")
Association <- .integrity_proxy("Association")
ASSOCIATION_TYPES <- .integrity_proxy("ASSOCIATION_TYPES")
Benchmark <- .integrity_proxy("Benchmark")
BenchmarkResult <- .integrity_proxy("BenchmarkResult")
Binary <- .integrity_proxy("Binary")
Certificate <- .integrity_proxy("Certificate")
CID <- .integrity_proxy("CID")
Code <- .integrity_proxy("Code")
Computation <- .integrity_proxy("Computation")
Compute <- .integrity_proxy("Compute")
Config <- .integrity_proxy("Config")
Configuration <- .integrity_proxy("Configuration")
Context <- .integrity_proxy("Context")
Credential <- .integrity_proxy("Credential")
Custom <- .integrity_proxy("Custom")
Database <- .integrity_proxy("Database")
Dataset <- .integrity_proxy("Dataset")
Declaration <- .integrity_proxy("Declaration")
DID <- .integrity_proxy("DID")
Document <- .integrity_proxy("Document")
Entity <- .integrity_proxy("Entity")
Error <- .integrity_proxy("Error")
Guardrail <- .integrity_proxy("Guardrail")
Media <- .integrity_proxy("Media")
Model <- .integrity_proxy("Model")
Prompt <- .integrity_proxy("Prompt")
Reasoning <- .integrity_proxy("Reasoning")
Service <- .integrity_proxy("Service")
SIGNER_ALGORITHMS <- .integrity_proxy("SIGNER_ALGORITHMS")
Signer <- .integrity_proxy("Signer")
Skill <- .integrity_proxy("Skill")
SystemPrompt <- .integrity_proxy("SystemPrompt")
Token <- .integrity_proxy("Token")
Tool <- .integrity_proxy("Tool")
UsageError <- .integrity_proxy("UsageError")
UUID <- .integrity_proxy("UUID")

.integrity_missing_module <- function() {
  structure(list(), class = "integrity_missing")
}

.integrity_module <- function() {
  python_ready <- tryCatch(
    reticulate::py_available(initialize = TRUE),
    error = function(e) FALSE
  )

  if (python_ready && reticulate::py_module_available("eqty_sdk")) {
    return(reticulate::import("eqty_sdk", convert = FALSE))
  }

  .integrity_missing_module()
}

.integrity_sdk <- function() {
  sdk <- .integrity_module()
  if (inherits(sdk, "integrity_missing")) {
    stop(
      "The 'eqty_sdk' Python module is unavailable in reticulate's active environment.\n",
      "If you selected Python manually, install it with: reticulate::py_install('eqty-sdk')",
      call. = FALSE
    )
  }
  sdk
}

.integrity_call <- function(name, ...) {
  function_object <- reticulate::py_get_attr(.integrity_sdk(), name)
  do.call(function_object, list(...))
}

.onLoad <- function(libname, pkgname) {
  # Declare the public Python dependency without initializing Python.
  # Reticulate provisions it in a managed environment when first needed.
  reticulate::py_require(
    packages = "eqty-sdk>=2.4.1",
    python_version = ">=3.10"
  )
}

#' Initialize the Eqty SDK
#'
#' Prepares the SDK's local state. Call this before changing configuration or
#' creating lineage statements. Supply a default context when assets and
#' computations should use it unless another context is selected explicitly.
#'
#' @param ... Arguments passed to `eqty_sdk.init()`, including `default_context`
#'   and `custom_dir`.
#' @return A Python-backed [Config] object for hashing, blob storage, directory
#'   filtering, and default-context settings.
#' @export
integrity_init <- function(...) {
  .integrity_call("init", ...)
}

#' Compute a CID for Bytes
#'
#' A CID is derived from content and changes when that content changes.
#'
#' @param ... Arguments passed to `eqty_sdk.get_cid_for_bytes()`.
#' @return A [CID] for the supplied bytes.
#' @export
get_cid_for_bytes <- function(...) .integrity_call("get_cid_for_bytes", ...)

#' Compute a CID for JSON
#'
#' @param ... Arguments passed to `eqty_sdk.get_cid_for_json()`.
#' @return A [CID] for the supplied JSON value.
#' @export
get_cid_for_json <- function(...) .integrity_call("get_cid_for_json", ...)

#' Compute a CID for a File or Directory
#'
#' @param ... Arguments passed to `eqty_sdk.get_cid_for_path()`.
#' @return A [CID] derived from the content at the supplied path.
#' @export
get_cid_for_path <- function(...) .integrity_call("get_cid_for_path", ...)

#' Clear the Local Blob Store
#'
#' Removes blobs cached in the SDK's local state. This is intended primarily
#' for testing, development, or an intentional local reset.
#'
#' @param ... Arguments passed to `eqty_sdk.purge_blob_store()`.
#' @return `NULL`.
#' @export
purge_blob_store <- function(...) .integrity_call("purge_blob_store", ...)

#' Clear the Local Statement Store
#'
#' Removes locally recorded lineage statements. Normal application workflows
#' generally preserve this state.
#'
#' @param ... Arguments passed to `eqty_sdk.purge_statement_store()`.
#' @return `NULL`.
#' @export
purge_statement_store <- function(...) .integrity_call("purge_statement_store", ...)

#' Verify a Lineage Statement
#'
#' Recomputes the statement identifier from its canonicalized JSON-LD content
#' and checks it against the statement's recorded identifier. The check runs
#' locally. Pass the manifest's context map when custom JSON-LD contexts are
#' involved.
#'
#' @param ... Arguments passed to `eqty_sdk.verify_statement()`.
#' @return `TRUE` when the statement identifier matches its content; otherwise
#'   `FALSE`.
#' @export
verify_statement <- function(...) .integrity_call("verify_statement", ...)

#' Verify a Verifiable Credential
#'
#' Checks a W3C Verifiable Credential proof locally. A statement identifier can
#' also be supplied to confirm that the credential refers to the expected
#' statement. Revocation and suspension status are outside this offline check.
#'
#' @param ... Arguments passed to `eqty_sdk.verify_vc()`.
#' @return `TRUE` when the credential proof and optional subject binding verify;
#'   otherwise `FALSE`.
#' @export
verify_vc <- function(...) .integrity_call("verify_vc", ...)

#' Access the Python Compute Decorator
#'
#' Provides direct access to `eqty_sdk.compute()`. R functions should usually
#' use [integrity_compute()], which executes the R function directly and records
#' its source and execution with [Code] and [Computation].
#'
#' @param ... Arguments passed to `eqty_sdk.compute()`.
#' @return The Python compute decorator or decorated callable returned by the
#'   SDK.
#' @export
compute <- function(...) .integrity_call("compute", ...)

#' Set the Active Signer
#'
#' Sets the signer used when higher-level SDK operations create signed
#' statements. Configure it during workflow setup after [integrity_init()].
#'
#' @param signer A signer created by [Signer].
#' @return `NULL`.
#' @export
integrity_set_active_signer <- function(signer) {
  .integrity_call("set_active_signer", signer)
}
