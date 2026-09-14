# EQTY lineage modeling reference

Read this reference when choosing node types, modeling an algorithm, or
recording a generated-code or agent workflow.

## Asset categories

Choose the smallest set of assets and computations that explains how a result
was produced.

| Node | Use it for |
|---|---|
| `Agent` | An autonomous or assisted actor, such as an LLM or QC agent. |
| `Benchmark` | A benchmark definition, evaluation protocol, test suite, or scoring procedure. |
| `BenchmarkResult` | Scores, metrics, pass/fail results, or other benchmark output. |
| `Binary` | A compiled executable, shared library, container payload, or binary program artifact. |
| `Certificate` | A certificate, signed attestation, or certificate-backed identity artifact. |
| `Code` | R, Python, SQL, shell, notebook, generated source, or other executable logic. |
| `Configuration` | Parameters and settings such as thresholds, seeds, model names, and feature flags. |
| `Credential` | A non-secret credential artifact or reference. Never store secret values. |
| `Custom` | A domain-specific artifact with no suitable built-in type. Supply a clear `asset_type`. |
| `Database` | A database, schema, table source, queryable store, or stable database reference. |
| `Dataset` | Input or output data, including frames, lists, files, record directories, and query results. |
| `Document` | A report, PDF, HTML page, Markdown file, specification, or protocol. |
| `Guardrail` | A validation rule, policy, safety check, quality gate, or acceptance criterion. |
| `Media` | An image, plot, audio file, video, or visualization. |
| `Model` | Model weights, a model package, endpoint description, or other distinct model artifact. |
| `Prompt` | A user prompt, task request, prompt template, or dynamic model instruction. |
| `Reasoning` | A permitted rationale or decision record. Never record hidden or sensitive reasoning. |
| `Skill` | A reusable capability or procedural instruction available to an agent. |
| `SystemPrompt` | System-level instructions governing an LLM or agent execution. |
| `Token` | Token data such as recorded model usage. Never use it for authentication secrets. |
| `Tool` | A callable tool, command, API operation, or external capability. |

Use `Database` for the queryable source and a separate `Dataset` for extracted
query results. `Asset` is the common base implementation and `AssetType` is its
enum; neither is an asset category.

For visual outputs intended for review, prefer a durable PNG, JPEG, SVG, or PDF
file registered as `Media`. Serialized graphics-device state such as an R
`recordPlot()` object is less useful for a human audit.

## Supporting objects

- `Context` groups statements, assets, and computations and defines a manifest
  boundary.
- `Computation` connects explicit input and output CIDs.
- `Compute` and `integrity_compute()` wrap executable logic and record its
  execution.
- `Signer` supplies the DID used to attribute and sign statements.
- `DID` represents decentralized identity; `Entity` represents an object with
  UUID-based identity rather than content-based identity.
- `CID` identifies content; `UUID` supplies identity independent of content.
- `Association` links CID, DID, or UUID subjects through a documented
  relationship.
- `Declaration` collects attachment CIDs, control CIDs, and additional fields.
  The SDK documents its serialization but no registration or finalization
  workflow.
- `Service` connects a graph to a remote Integrity Service. Local export does
  not require it.
- `Config` is runtime SDK configuration. Do not confuse it with the
  `Configuration` asset type.

## Algorithms and executions

Keep these concepts separate:

- `Compute` is an algorithmic step that can be executed. In R,
  `integrity_compute()` wraps the function that implements that algorithm and
  records its execution as a computation.
- `Code` is the source that implements an algorithm, including generated R
  source. It can be an input to a later `Compute` that executes it.
- `Configuration` contains the parameters applied to the algorithm, such as a
  threshold, random seed, model name, temperature, or feature flag. It is not
  input data or source code.
- `Dataset` is structured data read or produced by an algorithm. CSV files,
  data frames, database query results, and machine-readable discrepancy
  reports are common examples.
- `Document` is human-oriented content such as a PDF, specification,
  instruction file, Markdown file, narrative report, or final decision record.
- `Model` is a distinct model artifact when it should appear independently in
  the graph.
- `Computation` is the execution that consumed those inputs and produced the
  result.

For example, a configurable CSV transformation can be represented as:

```text
transformation Compute + Configuration + input CSV Dataset
                  -> execution -> output CSV Dataset
```

The wrapped transformation function is the algorithm. Its
`Configuration` records the values used for that run, while the input and
output CSV files are `Dataset` assets. If the same workflow consumes a PDF or
text instruction file, register that artifact as a `Document`.

When an `Agent` is the configured actor and provider or model selection is only
an agent setting, record those fields on the `Agent` rather than creating a
duplicate `Model` node.

Use `integrity_compute()` around the function that performs the recorded work.
Do not wrap credential loading, context setup, or manifest export as part of
the computation. Use an explicit `Computation` only when the stage is not an R
callable or the wrapper cannot preserve its behavior.

## Generated-code workflows

Represent prompt construction, the provider request, response processing,
generated-source execution, comparison, and validation as separate algorithms.
The advanced QC sample uses this structure so an auditor can distinguish what
the agent received, what it returned, what code was extracted, what data that
code processed, and how the result was checked.

```text
specification/instructions Document
                  -> prompt-construction Compute -> Prompt

Agent + SystemPrompt + Prompt
                  -> model-request Compute       -> raw provider response Document

raw provider response Document
                  -> response-processing Compute -> generated Code
                                                  + Token usage

generated Code + Configuration + input Dataset
                  -> generated-code execution Compute -> output Dataset

independent output Dataset + reference Dataset
                  -> comparison Compute           -> discrepancy-report Dataset

discrepancy-report Dataset + Guardrail
                  -> validation Compute           -> validation-result Document
```

In `samples/06-adsl-t14-qc-agent`, a text specification is a `Document`, while
SDTM CSV inputs, independent results, production reference data, and CSV
discrepancy reports are `Dataset` assets. The model call produces a `Document`
containing the complete raw provider response. Response processing validates
and saves the returned R source as `Code`, and records usage counts as a
`Token`. A later `Compute` executes that generated `Code` against the registered
input `Dataset` assets and produces a new `Dataset`.

Treat every arrow in the diagram as a meaningful algorithmic stage. Implement
an executable stage with `integrity_compute()` so the wrapped function and its
inputs and outputs are recorded together. The generated `Code` is an artifact
produced by response processing and consumed by the execution stage; it is not
itself the execution. Add a `Configuration` input when parameters affect that
execution, rather than putting those values in a `Dataset` or embedding them in
the generated `Code`.

Preserve the complete raw provider response available from the client,
including useful non-secret response metadata. Do not reduce it to the
extracted response text. Extract generated source and token counts during
response processing so both outputs remain linked to the same raw response.

Keep a `SystemPrompt` independent unless the workflow generates it. The dynamic
`Prompt` is the output of prompt construction because it combines the
specification with run-specific instructions and registered input locations.
Record validation rules as `Guardrail` when they should appear as explicit
assets. Use a `Dataset` for a structured comparison report such as CSV, a
`BenchmarkResult` for scores or pass/fail measurements, and a `Document` for a
human-readable report or final decision record.

When one generated-code workflow depends on another, reuse the shared content
CID across their contexts. The sample first produces an independent ADSL
`Dataset`; the later T14.2.01 workflow consumes that dataset and its QC report.
Each execution exports its own manifest, and the merger imports both manifests
to create the consolidated graph. Manifest merging does not represent an
algorithm, so it does not need an extra `Compute` or `Computation` node.
