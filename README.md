# EQTY SDK for R

This repository contains `eqty.sdk.r`, an R package that makes the
[`eqty-sdk`](https://pypi.org/project/eqty-sdk/) Python SDK available to R
users. It also contains examples and sample Integrity Manifests to help users
get started quickly.

## Overview

EQTY SDK for R is intended for data scientists, statisticians, ML engineers,
and teams that need a trustworthy record of how an output was produced. It
adds provenance to an R workflow without requiring its analytical logic to be
rewritten. 

It creates a clear record of the data, code, models, settings, and processing 
steps behind each result. Teams can use that record to understand what produced 
an output, reproduce a previous run, compare results, and investigate unexpected
changes. It also provides evidence that can be shared with reviewers, collaborators, 
and auditors without relying on incomplete notes or manual reconstruction of 
the workflow.

The provenance engine, asset models, content identifiers, signing, and manifest
operations are implemented by the Python SDK. The R package loads that
implementation through `reticulate` and exposes its classes and functions with
R-accessible names and helpers. R users can therefore create assets, record
computations, sign lineage statements, and export Integrity Manifests without
writing Python code.

## Repository contents

| Path | Contents |
|---|---|
| [`package/`](package/) | R package source, package documentation, metadata, and release notes |
| [`samples/`](samples/) | Examples from basic lineage to multi-stage agent workflows |
| [`samples/manifests/`](samples/manifests/) | Integrity Manifests that can be opened in EQTY Explorer |
| [`skills/`](skills/) | Installable agent skills for using and instrumenting R workflows with `eqty.sdk.r` |

## Start here

- Read the [R package guide](package/README.md) for requirements, installation,
  Python dependency management, API usage, and package development.
- Follow the [samples guide](samples/README.md) for runnable workflows and
  pre-generated Integrity Manifests. Open the manifests in EQTY Explorer to
  inspect assets, metadata, computations, and their connections, then compare
  each graph with the R code that created it.
- Use the [CRAN package page](https://cran.r-project.org/package=eqty.sdk.r) to install
  the released `eqty.sdk.r`package.
- For R code, use the [R package guide](package/README.md), generated R help,
  and R samples. The Python SDK is an implementation detail of the R package.

## Agent skill

Install the `eqty-sdk-r` skill for Codex, Claude Code, OpenCode, or another
supported coding agent with the `skills` CLI:

```bash
npx skills add https://github.com/eqtylab/integrity-r --skill eqty-sdk-r
```

The skill teaches an agent how to register R assets and computations, manage
contexts and signers, handle `_store` safely, and export local Integrity
Manifests. Its source is
[`skills/eqty-sdk-r/SKILL.md`](skills/eqty-sdk-r/SKILL.md).

By default, instrumentation is written to `<source-stem>-instrumented.R` with a
companion `<source-stem>-instrumented.md` lineage mapping.

The command installs only the `eqty-sdk-r` skill directory, including its
bundled references. It does not copy this repository's root `AGENTS.md`, package
guide, or sample folders into the target project. The installed skill is
self-contained and directs agents to use the R API without Python imports or
Python reflection.

Installing the skill does not install `eqty.sdk.r` or its Python backend. The R
package declares `eqty-sdk` through `reticulate::py_require()`, so reticulate may
download the managed Python dependency when an EQTY workflow first uses the
SDK. Planning and syntax-only validation should not trigger that provisioning.

## Development and releases

The R package source lives under `package/`, and its reference documentation is
generated from roxygen comments during the release build. 

Run`./build-package.sh` to regenerate the documentation, build the source tarball,
and perform the CRAN checks. The script stops if documentation generation or
packaging fails, or if `R CMD check` reports an error or warning. Successful
build and check results are written under `dist/`.

Pushing a version tag that matches the version in `package/DESCRIPTION` runs 
the release workflow and attaches the checked source tarball to a GitHub Release. 
See the [package guide](package/README.md#development-and-releases) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the current contribution policy. Use
the GitHub issue forms for bugs, questions, and feature requests.

## Security

Report suspected vulnerabilities privately according to
[SECURITY.md](SECURITY.md).

## License

This project is licensed under the [Apache License 2.0](LICENSE).
