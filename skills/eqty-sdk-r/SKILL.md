---
name: eqty-sdk-r
description: >
  Create verifiable provenance for R workflows with eqty.sdk.r. Use when
  writing, instrumenting, reviewing, or troubleshooting R code that registers
  EQTY assets, computations, signers, contexts, or Integrity Manifests. Do not
  use for Python-only eqty-sdk code.
license: Apache-2.0
---

# EQTY SDK for R

Use `eqty.sdk.r` to record the data, code, models, configuration, and processing
steps behind an R workflow. The resulting Integrity Manifest is a verifiable
lineage graph that supports audit, review, and reproducibility.

## Installation

Requirements: R, Python 3.10 or newer, and `reticulate` 1.41 or newer.

Install the released R package and load it:

```r
install.packages("eqty.sdk.r")
library(eqty.sdk.r)
```

The package declares its Python SDK dependency through
`reticulate::py_require()`. Reticulate normally provisions that dependency
automatically when an EQTY workflow first uses the SDK. Skill installation does
not install that Python dependency.

## Use the R interface

Treat this file, its bundled references, and the installed R help as the API
sources for R instrumentation. Read [`references/r-api.md`](references/r-api.md)
for supported construction patterns. Read
[`references/modeling.md`](references/modeling.md) for node selection,
algorithms, generated code, agents, or validation.

Do not use `reticulate::import()`, Python reflection, or the Python SDK
implementation to discover how to write R instrumentation. Do not import
`eqty_sdk` directly. Use `library(eqty.sdk.r)` and its exported R names in the
instrumented workflow.

The repository-level `AGENTS.md`, package guide, and samples are not installed
with this skill. Do not assume they are available in the user's project. The
bundled skill and references must be sufficient for ordinary instrumentation.

Choose the guidance that matches the workflow:

- For ordinary data transformations and reports, use the standard workflow
  below and the patterns in `references/r-api.md`.
- For plots, also use the durable plot guidance in `references/r-api.md`.
- For node selection, generated code, model agents, comparisons, or validation,
  read `references/modeling.md` before planning the graph.

## Instrument an existing R file

When a user asks to instrument an existing R file, perform a read-only
preflight before proposing changes:

1. Confirm that R is installed and record its version with
   `Rscript --version`.
2. Confirm that Python 3.10 or newer is installed using the environment's
   configured Python command. Do not select or replace the project's Python
   interpreter during this check.
3. Confirm that `eqty.sdk.r` is installed and record its version without
   loading its namespace:

   ```bash
   Rscript -e 'p <- installed.packages(); if (!("eqty.sdk.r" %in% rownames(p))) quit(status = 1); cat(p["eqty.sdk.r", "Version"], "\n")'
   ```

4. Read the complete target R file and identify its entry point, parameters,
   dependencies, working-directory assumptions, inputs, outputs, meaningful
   processing stages, and sensitive data.
5. Check whether the project is under source control and whether the target R
   file is tracked. For Git repositories, use read-only commands such as
   `git rev-parse --is-inside-work-tree`, `git status --short`, and
   `git ls-files --error-unmatch -- path/to/file.R`.

If the project is not under source control, or the target and related files are
untracked, warn the user that the original state may be difficult to recover.
Recommend adding and committing the existing files before instrumentation. Do
not initialize a repository, stage files, or create a commit unless the user
explicitly asks.

If a prerequisite is absent or incompatible, report it and provide the command
the user can use to install or configure it. Do not install dependencies or
modify the R workflow during preflight unless the user has already authorized
that work.

Keep preflight and syntax validation R-only and non-initializing. Do not load
`eqty.sdk.r`, initialize `reticulate`, access Python-backed SDK objects, or
trigger creation or download of a managed Python environment merely to inspect
signatures. Loading and provisioning belong to actual workflow execution and
require the user's authorization to run that workflow or install dependencies.

Write an instrumentation plan before creating files. The plan should state:

- the source file and proposed instrumented destination;
- the detected R, Python, and `eqty.sdk.r` versions;
- the source-control state and whether the source file is tracked;
- each proposed asset, its node type, and whether its content will be stored;
- each computation and its direct inputs and outputs;
- the context, signer, and manifest destination;
- behavior-preservation decisions, assumptions, and unresolved risks.

Before proposing a destination, check whether it already exists. Follow an
existing project convention; otherwise use `<source-stem>-instrumented.R`,
`<source-stem>-instrumented.md`, and `output/manifest.json`. Never overwrite the
source, an existing instrumented file, a mapping, a manifest, or another
workflow artifact unless the user explicitly instructs you to replace that
exact file.
If a proposed destination exists, report the collision and offer a new filename
where the project permits it. If `output/` does not exist, disclose that it will
be created after confirmation. When a project requires a fixed destination,
disclose the collision and wait for explicit replacement instructions.

Present the plan to the user and wait for explicit confirmation. Do not create
or modify the instrumented R file, mapping file, or other workflow artifacts
until that confirmation is received. After confirmation, implement the agreed
plan and report any material deviation before expanding its scope.

## Standard workflow

1. Create a context and initialize the SDK.
2. Load or create a local signer and make it active.
3. Register the direct inputs and outputs as typed assets.
4. Record each meaningful transform with `integrity_compute()` or
   `Computation`.
5. Export the context as an Integrity Manifest.

```r
library(eqty.sdk.r)

ctx <- Context$new("Example workflow")
invisible(integrity_init(default_context = ctx))

signer <- Signer$load_or_create(name = "example-r-signer")
invisible(integrity_set_active_signer(signer))
signer_did <- DID$from_signer(signer, name = "Workflow signer")

input_data <- data.frame(value = c(1, 2, 3))
input <- Dataset$with_context(ctx)$from_object(
  input_data,
  name = "Input values"
)

summary_data <- data.frame(total = sum(input_data$value))
output <- Dataset$with_context(ctx)$from_object(
  summary_data,
  name = "Summary"
)

invisible(
  Computation$with_context(ctx)$new(
    name = "Calculate total"
  )$add_input_cid(
    input$cid
  )$add_output_cid(
    output$cid
  )$finalize()
)

invisible(ctx$export(integrity_path("manifest.json")))
```

Wrap setup and export calls in `invisible()` when their return values are not
used. This prevents Python-backed values such as `Config` or `None` from being
printed during `Rscript` execution.

## Choose assets by meaning

Use the most specific built-in category. Read
[`references/modeling.md`](references/modeling.md) when choosing a node type or
modeling algorithms, generated code, agent execution, or validation. Use
`Custom` with a clear `asset_type` only when no built-in category fits.

All typed assets support the same construction choices:

- `from_path()` for a file or directory that is the actual artifact.
- `from_object()` for an in-memory R value.
- `from_cid()` when an existing CID is authoritative and the content is not
  supplied locally.

Use `with_context(ctx)` so graph membership is explicit. Pass Python paths with
`integrity_path()` and Python dictionaries with `integrity_dict()`.

```r
source_data <- Dataset$with_context(ctx)$from_path(
  integrity_path("data/input.csv"),
  name = "Input data"
)

settings <- Configuration$with_context(ctx)$from_object(
  integrity_dict(threshold = 0.8, seed = 42),
  name = "Analysis settings"
)

snapshot <- Custom$with_context(
  ctx,
  asset_type = "FeatureStoreSnapshot"
)$from_path(integrity_path("data/features"), name = "Feature snapshot")
```

## Decide whether to store content

Every registered asset receives a CID whether its content is stored or not.

- `_store = TRUE` retains the content in the local blob store and packages it
  with an exported manifest. Use it when the manifest must contain the content
  for inspection or reproduction.
- `_store = FALSE` records the CID, metadata, and lineage without retaining the
  original content. Use it for large, confidential, personal, or otherwise
  sensitive material.

Never store credentials, API keys, passwords, private keys, `.Renviron`, vault
responses, or resolved secret values. `from_cid()` has no `_store` option
because it receives an identifier without the original content.

## Choose the computation API

Use `integrity_compute()` when an R function performs the recorded operation.
It registers the function as `Code` and connects its arguments and result:

```r
add_values <- integrity_compute(
  context = ctx,
  metadata = list(name = "Add values"),
  func = function(x, y) x + y
)
total <- add_values(10, 20)
```

Its `_store` argument controls storage of the registered R source and the
inputs and outputs hashed by the wrapper. It defaults to `FALSE`. Set it to
`TRUE` only when all of that content is safe to include.

When the wrapped function produces several assets, return them in an ordinary
R `list()` and consume the wrapper's result by name or position.

Use `Computation` when lineage is explicit but the operation is not an R
function call, or when exact input and output CIDs are already available. Add
every direct input and output, including the relevant `Code` or
`Configuration` assets when they materially affect the stage, then call
`finalize()`.

When manually registering a script as `Code`, register the source that is
actually executed. For an instrumented copy, this is normally
`<source-stem>-instrumented.R`. Register the original source separately only
when the before-and-after relationship is useful to the audit; do not
substitute it for the executed source. `integrity_compute()` already registers
its wrapped R function as `Code`, so do not add a duplicate code asset for that
function.

## Contexts and manifests

`Context` defines the graph and manifest boundary. Use parent and child
contexts for related runs or subgraphs:

```r
project <- Context$new("Example project")
run <- Context$with_parent(project)$new("Run 1")
invisible(integrity_init(default_context = run))
```

Use `Context$import_manifest(integrity_path(path))` when a later execution must
extend an earlier local graph. Use `Context$export(integrity_path(path))` to
write the combined statements and retained blobs. Local manifest generation
does not require `Service` or Governance Studio credentials.

## Signers and local state

Always use `Signer$load_or_create()` for a stable local signer, activate it with
`integrity_set_active_signer()`, and optionally attach non-secret identity
metadata with `DID$from_signer()`.

The SDK stores local state and signing keys in `.eqty_sdk/` by default. Preserve
it when signer identity must remain stable, restrict access to it, and never
register or commit it. Pass `custom_dir` to `integrity_init()` when state must
live elsewhere.

## Preserve the workflow

When instrumenting existing R code, keep its functions, arguments, outputs,
working-directory behavior, and analytical logic intact. Register inputs
before they are consumed and outputs after they materialize. Record meaningful
stages such as retrieval, parsing, cleaning, joining, modelling, plotting,
report generation, and validation; do not create nodes for temporary variables
that do not help explain the result.

Prefer one computation for one meaningful algorithm. Do not turn each
assignment or intermediate vector into a separate computation or asset. Promote
an intermediate value only when it crosses a stage boundary, is reused by
another workflow, is independently reviewed, or is necessary to explain the
result.

For plots and other visual outputs, register an existing durable file such as
PNG, JPEG, SVG, or PDF as `Media`. Avoid serialized graphics-device objects such
as `recordPlot()` when the result is intended for human audit. If the original
workflow does not create a durable plot file, disclose the proposed additional
output in the plan before adding it.

Do not execute a workflow or contact an external service merely to validate
instrumentation unless the user asks. Prefer a syntax-only check when it is
sufficient.

## Resources

- [R API patterns](references/r-api.md)
- [Lineage modeling reference](references/modeling.md)
- [R package guide](https://github.com/eqtylab/integrity-r/tree/main/package)
- [R samples](https://github.com/eqtylab/integrity-r/tree/main/samples)
- [IPFS CID specification](https://specs.ipfs.tech/cid/)
