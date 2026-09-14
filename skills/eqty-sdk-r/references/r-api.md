# EQTY SDK for R API patterns

Use these R patterns when instrumenting a workflow. They are bundled with the
skill so API discovery does not require the source repository, network access,
Python imports, or Python reflection.

## API source order

1. Follow `SKILL.md` for the instrumentation workflow and safety rules.
2. Use this reference for R construction patterns.
3. Use `modeling.md` to choose node types and graph structure.
4. If `eqty.sdk.r` is installed and more detail is needed, read its generated R
   help with `help(package = "eqty.sdk.r")` or a specific `help()` topic.

Do not call `library(eqty.sdk.r)`, initialize `reticulate`, or invoke a
Python-backed SDK object merely to inspect the API. Never call
`reticulate::import()` for R instrumentation. A syntax check can use
`parse(file = "path/to/file.R")` without loading the package.

## Context and signer

```r
library(eqty.sdk.r)

ctx <- Context$new("Descriptive workflow name")
invisible(integrity_init(default_context = ctx))

signer <- Signer$load_or_create(name = "stable-local-signer")
invisible(integrity_set_active_signer(signer))
signer_did <- DID$from_signer(
  signer,
  name = "Workflow signer",
  description = "Local signer for this workflow"
)
```

Use `integrity_path()` when an SDK method expects a Python path and
`integrity_dict()` when it expects a Python dictionary. Do not import `pathlib`
or construct dictionaries through `reticulate`.

## Asset factories

Every built-in typed asset uses the same three factory choices:

```r
input <- Dataset$with_context(ctx)$from_path(
  integrity_path("data/input.csv"),
  name = "Input data",
  description = "CSV consumed by the analysis"
)

settings <- Configuration$with_context(ctx)$from_object(
  integrity_dict(threshold = 0.8, seed = 42),
  name = "Analysis settings"
)

existing <- Dataset$with_context(ctx)$from_cid(
  CID(existing_cid_string),
  name = "Previously registered data"
)
```

Use one factory per artifact. Use `from_path()` for the actual file or
directory, `from_object()` for an in-memory value, and `from_cid()` only when an
existing CID is authoritative.

## Executable R algorithms

Use `integrity_compute()` when an R function performs the recorded algorithm.
The wrapper registers the function source as `Code`, converts its arguments to
input assets, and records its returned assets as outputs.

```r
generate_report <- integrity_compute(
  context = ctx,
  metadata = list(
    name = "Generate report",
    description = "Creates a report from registered input data"
  ),
  `_store` = TRUE,
  func = function(input_dataset, configuration) {
    input_path <- as.character(integrity_resolve_path(input_dataset))
    settings <- configuration$value

    result <- utils::read.csv(input_path)
    result <- result[result$score >= as.numeric(settings$threshold), ]
    utils::write.csv(result, "output/report.csv", row.names = FALSE)

    Dataset$with_context(ctx)$from_path(
      integrity_path("output/report.csv"),
      name = "Filtered report"
    )
  }
)

report <- generate_report(input, settings)
```

Set the wrapper's `_store = TRUE` only when the function source and automatically
registered values contain no secrets or sensitive information.

## Explicit lineage

Use `Computation` when the relationship is explicit lineage rather than an R
function call, or when wrapping the operation would change its behavior:

```r
invisible(
  Computation$with_context(ctx)$new(
    name = "Generate report",
    description = "Connects the executed code and input data to the report"
  )$add_input_cid(
    executed_code$cid
  )$add_input_cid(
    input$cid
  )$add_output_cid(
    report$cid
  )$finalize()
)
```

Register the instrumented R file that is actually run as `executed_code`.
Avoid a separate computation for every assignment or temporary value.

## Durable plot output

When a workflow writes a plot, register the resulting image or PDF as `Media`:

```r
plot_output <- Media$with_context(ctx)$from_path(
  integrity_path("output/plot.png"),
  name = "Analysis plot",
  description = "Human-readable plot produced by the workflow"
)
```

Use an existing output when possible. Adding a new plot file changes the
workflow's outputs and must be included in the instrumentation plan.

## Manifest export

Follow an existing project convention. Otherwise export to
`output/manifest.json` after checking for a collision and creating `output/`
only as disclosed in the confirmed plan.

```r
invisible(ctx$export(integrity_path("output/manifest.json")))
```
