# EQTY SDK R samples

These samples show how to add verifiable lineage to R workflows, starting with
the core SDK concepts and progressing to instrumented functions and multi-stage
agent workflows. Use the table to choose a sample, open its generated graph in
EQTY Explorer, and compare the graph with the R code that produced it.

Run each script from its own sample folder. Generated files, including the
manifest produced by the sample, are written to that folder's `output/`
directory. Git ignores the contents of these directories, and generated output
must not be committed. Curated manifests for viewing in EQTY Explorer are kept
separately in [`samples/manifests/`](manifests/).

Install the released R package before running a sample:

```r
install.packages("eqty.sdk.r")
```

When running individual samples, install the optional dependencies used by
samples 04–06 with:

```bash
Rscript samples/install-dependencies.R
```

The all-samples runner invokes this installer automatically.

**Local EQTY setup:** all samples use a local signer and export manifests
locally. They do not authenticate to or register with Governance Studio or
another EQTY cloud service.

| Sample | EQTY SDK features demonstrated | R script | URL |
|---|---|---|---|
| [01: Basic sample](#01-basic-sample) | Minimal local lineage with a signer, two in-memory assets, an explicit computation, and manifest export. | [`sample-register.R`](01-basic-sample/sample-register.R) | [View](https://explorer.eqtylab.io/?manifest_url=https://raw.githubusercontent.com/eqtylab/integrity-r/main/samples/manifests/01-manifest.json) |
| [02: All nodes](#02-all-nodes) | Every built-in asset category connected across a four-stage synthetic customer-support workflow. | [`sample-all-nodes.R`](02-all-nodes/sample-all-nodes.R) | [View](https://explorer.eqtylab.io/?manifest_url=https://raw.githubusercontent.com/eqtylab/integrity-r/main/samples/manifests/02-manifest.json) |
| [03: Time lineage](#03-time-lineage) | Two historical sequences that converge, demonstrating sequential computations, multiple inputs, computation metadata, and a parent-child context. | [`sample-history.R`](03-time-lineage/sample-history.R) | [View](https://explorer.eqtylab.io/?manifest_url=https://raw.githubusercontent.com/eqtylab/integrity-r/main/samples/manifests/03-manifest.json) |
| [04: Plot](#04-plot) | DID metadata, `integrity_compute()`, registered inputs and outputs, and R source stored in the Integrity Manifest. | [`sample-verifiable-plot.R`](04-plot/sample-verifiable-plot.R) | [View](https://explorer.eqtylab.io/?manifest_url=https://raw.githubusercontent.com/eqtylab/integrity-r/main/samples/manifests/04-manifest.json) |
| [05: GitHub data provenance](#05-github-data-provenance) | Provenance from Git commit verification through CSV retrieval to a derived plot. | [`generate-verifiable-plot-gitcommit.R`](05-plot-validation/generate-verifiable-plot-gitcommit.R) | [View](https://explorer.eqtylab.io/?manifest_url=https://raw.githubusercontent.com/eqtylab/integrity-r/main/samples/manifests/05-manifest.json) |
| [06: ADSL and T14 QC agents](#06-adsl-and-t14-qc-agents) | Two dependent study stages executed separately, with their manifests later combined into one lineage graph. | [`sample_01_adsl_qc_agent.R`](06-adsl-t14-qc-agent/sample_01_adsl_qc_agent.R)<br>[`sample_02_t14_2_01_agent.R`](06-adsl-t14-qc-agent/sample_02_t14_2_01_agent.R)<br>[`sample_03_merge.R`](06-adsl-t14-qc-agent/sample_03_merge.R) | [View](https://explorer.eqtylab.io/?manifest_url=https://raw.githubusercontent.com/eqtylab/integrity-r/main/samples/manifests/06-01-manifest-adsl.json)<br>[View](https://explorer.eqtylab.io/?manifest_url=https://raw.githubusercontent.com/eqtylab/integrity-r/main/samples/manifests/06-02-manifest-t14-2-01.json)<br>[View](https://explorer.eqtylab.io/?manifest_url=https://raw.githubusercontent.com/eqtylab/integrity-r/main/samples/manifests/06-manifest.json) |

## Run all samples

From the repository root:

```bash
./samples/run-all-samples.sh
```

The runner first installs any missing optional dependencies, then changes to
each sample folder before invoking `Rscript`. It stops on the first failure.
Sample 05 contacts GitHub, and sample 06 requires Gemini credentials.

## 01: Basic sample

This is the smallest complete EQTY SDK example. It initializes a local
`Context` and `Signer`, creates an in-memory `Code` input and `Document` output,
and connects their CIDs with an explicit `Computation`. It then exports the
resulting statements and stored asset content in a local Integrity Manifest.

From `samples/01-basic-sample/`:

```bash
Rscript sample-register.R
```

The manifest is written to `output/manifest.json`.

## 02: All nodes

This sample places every built-in asset category into a four-stage synthetic
customer-support workflow. It uses small synthetic values and performs no model
inference, network requests, or substantive data processing. The workflow
connects `Agent`, `Benchmark`, `BenchmarkResult`, `Binary`, `Certificate`, `Code`,
`Configuration`, `Credential`, `Custom`, `Database`, `Dataset`, `Document`,
`Guardrail`, `Media`, `Model`, `Prompt`, `Reasoning`, `Skill`, `SystemPrompt`,
`Token`, and `Tool` through computations in one graph.

From `samples/02-all-nodes/`:

```bash
Rscript sample-all-nodes.R
```

The manifest is written to `output/manifest.json`.

## 03: Time lineage

This sample represents two sequences from Roman history as lineage. One follows
the final years of the Roman Republic, and the other follows the rise of Julius
Caesar. The sequences converge at Caesar's appointment as dictator and again at
his assassination. The graph demonstrates sequential computations, computations
with multiple inputs, a child `Context`, and custom date and year metadata.

From `samples/03-time-lineage/`:

```bash
Rscript sample-history.R
```

The manifest is written to `output/manifest.json`.

## 04: Plot

This sample creates a `DID` from the active local signer and attaches public
metadata to that identity. It then uses `integrity_compute()` to wrap a normal R
plotting function, record its `Dataset` and `Configuration` inputs, and connect
them to the returned output asset. Setting `_store = TRUE` on the wrapper stores
the R function source as a `Code` asset in the exported Integrity Manifest.

From `samples/04-plot/`:

```bash
Rscript sample-verifiable-plot.R
```

The manifest is written to `output/manifest.json`.

## 05: GitHub data provenance

This sample records the provenance of data retrieved from GitHub and used to
generate a plot. It captures the requested repository and revision, the Git
commit's signature-verification result, the CSV downloaded from that exact
revision, and the plot derived from the CSV. Separate computations connect
commit verification, data retrieval, and plot generation in one graph.

From `samples/05-plot-validation/`:

```bash
Rscript generate-verifiable-plot-gitcommit.R
```

The manifest is written to `output/manifest.json`.

## 06: ADSL and T14 QC agents

This advanced sample models a real multi-step study whose stages may run at
different times or on different computers. The first script executes the ADSL
QC stage and exports its own lineage manifest. The second script executes the
dependent T14.2.01 QC stage using the independent ADSL dataset and discrepancy
report produced by the first stage, then exports another manifest. Registering
those files in both stages produces shared content CIDs that preserve the
relationship between their separate lineage graphs. The third script imports
both manifests and exports a single consolidated lineage graph for the study.

The workflow also demonstrates `Agent`, `Prompt`, `SystemPrompt`, `Document`,
`Code`, `Token`, and `Dataset` assets; `integrity_compute()` around actual R
functions; full provider-response capture; multiple outputs; stored R source;
and terminal validation results.

From `samples/06-adsl-t14-qc-agent/`, run:

```bash
Rscript sample_01_adsl_qc_agent.R
Rscript sample_02_t14_2_01_agent.R
Rscript sample_03_merge.R output/manifest-adsl.json output/manifest-t14-2-01.json
```

The agent workflows require the `ellmer` package and Gemini credentials.

The first two commands write `output/manifest-adsl.json` and
`output/manifest-t14-2-01.json`. The merger accepts one or more manifest paths
and writes the combined graph to `output/manifest.json`.
