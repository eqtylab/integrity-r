#' @keywords internal
"_PACKAGE"

#' Eqty SDK for R
#'
#' An R interface for building integrity manifests around data, models, prompts,
#' agents, computations, and their lineage. It exposes the Python `eqty_sdk`
#' API through R names such as [Dataset], [Context], and [Signer], loaded lazily
#' through `reticulate`.
#'
#' Start with [integrity_init()], which prepares the SDK's local state and
#' returns a [Config]. A [Context] groups related assets, computations, and
#' statements and defines what is written when that context is exported.
#' Configure an active [Signer] before creating statements so they are
#' attributed to its DID.
#'
#' Assets represent tracked inputs and outputs. Create them from an R object, a
#' file or directory path, or an existing [CID]. Use [integrity_compute()] to
#' wrap an R function and capture its execution, or [Computation] when input and
#' output CIDs need to be added explicitly.
#'
#' The exported SDK classes are Python-backed and retain their method syntax.
#' Use [integrity_path()] for methods that require a Python path and
#' [integrity_dict()] for methods that require a Python dictionary.
#'
#' @name eqty.sdk.r-package
#' @aliases eqty.sdk.r
NULL

#' Python-backed Eqty SDK Types
#'
#' These names are lazy bindings to the matching `eqty_sdk` classes and enums.
#' They are available after `library(eqty.sdk.r)` and retain the constructors,
#' factories, properties, and methods of the installed Python SDK.
#'
#' The built-in asset categories are `Agent`, `Benchmark`, `BenchmarkResult`,
#' `Binary`, `Certificate`, `Code`, `Configuration`, `Credential`, `Custom`,
#' `Database`, `Dataset`, `Document`, `Guardrail`, `Media`, `Model`, `Prompt`,
#' `Reasoning`, `Skill`, `SystemPrompt`, `Token`, and `Tool`. They share a common
#' construction pattern. Use `with_context(ctx)` when the asset belongs to a
#' specific context.
#'
#' [CID] identifies content and is used to connect computation inputs and
#' outputs. [UUID] identifies objects whose identity is not derived from their
#' content. [DID] identifies signers and other entities referenced by provenance
#' statements.
#'
#' [Service] connects the SDK to a remote Integrity Service. It is unnecessary
#' when a workflow only exports a local manifest.
#'
#' @name eqty-sdk-types
#' @aliases Agent
#' @aliases Asset
#' @aliases AssetType
#' @aliases Association
#' @aliases ASSOCIATION_TYPES
#' @aliases Benchmark
#' @aliases BenchmarkResult
#' @aliases Binary
#' @aliases Certificate
#' @aliases CID
#' @aliases Code
#' @aliases Computation
#' @aliases Compute
#' @aliases Config
#' @aliases Configuration
#' @aliases Context
#' @aliases Credential
#' @aliases Custom
#' @aliases Database
#' @aliases Dataset
#' @aliases Declaration
#' @aliases DID
#' @aliases Document
#' @aliases Entity
#' @aliases Error
#' @aliases Guardrail
#' @aliases Media
#' @aliases Model
#' @aliases Prompt
#' @aliases Reasoning
#' @aliases Service
#' @aliases SIGNER_ALGORITHMS
#' @aliases Signer
#' @aliases Skill
#' @aliases SystemPrompt
#' @aliases Token
#' @aliases Tool
#' @aliases UsageError
#' @aliases UUID
NULL

#' Direct access to the Python SDK module
#'
#' `eqty` is retained for compatibility. Prefer the exported R names such as
#' [Dataset], [Context], and [integrity_init()] for new code.
#'
#' @name eqty
#' @export
NULL
