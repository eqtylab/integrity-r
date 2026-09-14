# R code instrumentation repository guide

Use this guide when a user supplies an R script and asks for EQTY
instrumentation. Preserve the script's behavior while adding useful lineage.

## Sources and scope

Read [`skills/eqty-sdk-r/SKILL.md`](skills/eqty-sdk-r/SKILL.md) before writing
instrumentation. It contains the portable SDK workflow, asset factories,
computation choices, signer setup, storage rules, and security requirements.
For supported R construction patterns, read
[`skills/eqty-sdk-r/references/r-api.md`](skills/eqty-sdk-r/references/r-api.md).
For node selection or generated-code workflows, also read
[`skills/eqty-sdk-r/references/modeling.md`](skills/eqty-sdk-r/references/modeling.md).

Use these sources according to their role:

- `package/R/*.R` and `package/DESCRIPTION` define the R API and declared
  dependencies.
- `skills/eqty-sdk-r/` defines reusable agent guidance.
- This file defines repository-specific instrumentation and sample rules.
- `background.md` explains concepts for human readers.
- `samples/README.md` defines the sample catalog, order, and commands.

Do not infer SDK capabilities that are absent from the R package exports,
generated R documentation, and bundled skill references. Do not use Python
reflection or direct Python imports to discover the R API.

## Repository contents

| Path | Contents |
|---|---|
| [`package/`](package/) | R package source, package documentation, metadata, and release notes |
| [`samples/`](samples/) | Examples from basic lineage to multi-stage agent workflows |
| [`samples/manifests/`](samples/manifests/) | Integrity Manifests that can be opened in EQTY Explorer |
| [`skills/`](skills/) | Installable agent skills for using and instrumenting R workflows with `eqty.sdk.r` |

## Required outcome

Before creating or modifying files, complete the skill's environment preflight,
write the instrumentation plan, present it to the user, and wait for explicit
confirmation. Read-only inspection and planning do not require confirmation.

After confirmation, produce:

1. An instrumented script named `<original-stem>-instrumented.R`, unless the user
   specifies another destination.
2. A short `<original-stem>-instrumented.md` mapping of source inputs, generated
   outputs, code assets, computations, contexts, assumptions, and manifest
   paths.
3. A brief handoff describing required local configuration and assumptions.

Do not overwrite the supplied script or any existing destination, mapping,
manifest, or workflow artifact unless the user explicitly names that file for
replacement. If the default destination already exists, propose a new filename
in the plan.

## Analyze before editing

Read the complete script and identify:

- its entry point, parameters, dependencies, and working-directory assumptions;
- files, directories, queries, API responses, and in-memory inputs that affect
  its result;
- generated data, plots, models, reports, files, and returned values;
- meaningful processing stages and their direct inputs and outputs;
- sensitive data and credentials.

Use the smallest graph that explains the workflow. Do not create nodes for
temporary variables or individual lines of code. If an essential choice cannot
be inferred, record a conservative assumption in the mapping file. Ask the
user only when the choice materially changes the recorded lineage.

## Repository instrumentation conventions

- Load `library(eqty.sdk.r)` and use its exported objects and helpers. Never
  import `eqty_sdk` directly from generated R code.
- Use `with_context(ctx)` for every asset and computation, even when `ctx` is
  the default context.
- Use `integrity_path()` for Python path arguments and `integrity_dict()` for
  Python dictionaries.
- Register inputs before the stage that consumes them and outputs after they
  materialize.
- Register a `Code` asset for the executed source. Generated source is a
  separate `Code` asset.
- Include every direct input and output CID on each meaningful computation,
  including relevant code and configuration assets.
- Use `integrity_compute()` when an R function performs the recorded stage.
  Use `Computation` for explicit lineage that is not an R callable or when the
  wrapper cannot preserve behavior.
- Preserve ordinary functions, user-facing arguments, outputs, and analytical
  logic. Add instrumentation around existing behavior.
- Preserve useful custom metadata from the workflow. Use clear field names and
  serializable values.
- Wrap unused setup, signer, import, and export results in `invisible()`.
- Use `cat()` with an explicit `"\n"` for text logs. Reserve `print()` for
  object-specific formatting.

## Repository manifest rules

Every local example must export its consolidated graph to the literal relative
path `output/manifest.json`.

If that manifest already exists, disclose the collision in the plan. Do not run
an export that replaces it without explicit user instruction.

- Sample `output/` directories contain a committed `.gitkeep`. Do not create or
  check for that directory in generated code.
- Ensure generated files under `output/` remain ignored.
- Local examples export only. Do not create a `Service`, authenticate a signer
  to a service, or register the context with Governance Studio.
- Use `Signer$load_or_create()` for local signers.
- Keep `.eqty_sdk/` or a configured `custom_dir` private, persistent when a
  stable signer is required, and outside the lineage graph.
- Repeat the skill's secret and `_store` checks before embedding content. Never
  register credentials, resolved secrets, private keys, `.Renviron`, or local
  SDK state.

## Suggested generated-script structure

Use clearly labelled sections:

1. configuration and package setup;
2. context and signer setup;
3. input and code registration;
4. original processing logic;
5. output registration and computation links;
6. manifest export.

Keep paths relative to the instrumented script or accept them as parameters.
Do not overwrite inputs. Explain lineage decisions in comments rather than
obvious R syntax.

## Combining separate executions

When a later execution extends an earlier graph, import the existing manifest
before registering the later stage. Re-register shared content or use its
authoritative CID so both stages refer to the same identifier. Export the
extended graph back to `output/manifest.json`.

When executions must remain separate:

1. Export each execution to a clearly named intermediate manifest under
   `output/`.
2. Create a merger context and import every intermediate manifest.
3. Export the merger to `output/manifest.json`.

Importing statements and blobs is sufficient. Do not invent an asset or
computation solely to represent the merge. Use
`samples/06-adsl-t14-qc-agent/` as the working reference.

## Samples

Follow the sample order and descriptions in `samples/README.md`. Preserve that
order when adding links or documentation. The advanced sample is the reference
for agent prompts and responses, generated code, multiple compute outputs,
separate executions joined by shared CIDs, and manifest merging.

## Verification and handoff

Do not execute the workflow, contact external services, or submit a manifest
unless the user asks. Syntax-only checks are allowed when they do not execute
the script.

Before handoff:

- confirm there is no `reticulate::import()` call or other direct Python API
  access;
- confirm `output/.gitkeep` exists for repository samples;
- confirm the script does not create the sample output directory;
- confirm other required parent directories exist or are created by the
  original workflow;
- report the instrumented script, mapping file, manifest destination, local
  configuration, and assumptions.
