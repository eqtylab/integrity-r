# EQTY SDK for R

The `eqty.sdk.r` is intended for data scientists, statisticians, ML engineers, and
teams that need a trustworthy record of how an output was produced. It records
the data, code, models, settings, and processing steps behind a result without
requiring the workflow's analytical logic to be rewritten. The resulting
Integrity Manifest can support review, audit, reproducibility, and
collaboration across teams and systems.

This package is an R package that makes the public
[`eqty-sdk`](https://pypi.org/project/eqty-sdk/) Python SDK available to R
users.

## Requirements

- R
- Python 3.10 or newer
- `reticulate` 1.41 or newer

## Installation

Install the released package and its R dependencies from CRAN:

```r
install.packages("eqty.sdk.r")
```

To install the development version from a repository checkout:

```r
install.packages("pak")
pak::local_install("package")
```

## Python dependency management

The package declares `eqty-sdk>=2.4.1` and Python 3.10 or newer with
`reticulate::py_require()`. On first use, reticulate creates or reuses a managed
Python environment and installs the Python dependency from public PyPI. The
default setup does not require a separate `pip` command.

If `RETICULATE_PYTHON`, `reticulate::use_python()`, or another setting selects a
specific Python environment, that environment must already contain the Python
package:

```r
reticulate::py_install("eqty-sdk")
library(eqty.sdk.r)
```

## Quick start

```r
library(eqty.sdk.r)

ctx <- Context$new("Example R workflow")
invisible(integrity_init(default_context = ctx))

signer <- Signer$load_or_create(name = "example-r-signer")
invisible(integrity_set_active_signer(signer))

input_data <- data.frame(value = c(1, 2, 3))
input <- Dataset$with_context(ctx)$from_object(
  input_data,
  name = "Input values",
  description = "Values to sum",
  `_store` = TRUE
)

summary_data <- data.frame(total = sum(input_data$value))
output <- Dataset$with_context(ctx)$from_object(
  summary_data,
  name = "Summary",
  description = "Calculated total",
  `_store` = TRUE
)

invisible(
  Computation$with_context(ctx)$new(
    name = "Calculate total",
    description = "Sums the registered input values"
  )$add_input_cid(
    input$cid
  )$add_output_cid(
    output$cid
  )$finalize()
)

invisible(ctx$export(integrity_path("manifest.json")))
cat("Manifest written to manifest.json\n")
```

Review the important usage notes below before storing asset content.

## Core concepts

This section provides a concise introduction to the main objects and workflows.
Use the generated R help for the supported R API, signatures, options, and
behavior. The Python SDK documentation describes the underlying implementation;
it is not the source for R syntax and does not replace the R interface.

### Overview

The provenance engine, asset models, content identifiers, signing, and
manifest operations are implemented by the Python SDK. The R package loads
that implementation through `reticulate` and exposes it through R-accessible
types and helpers.

- Content identifiers derived from files, directories, and in-memory objects.
- Typed assets including `Dataset`, `Code`, `Model`, `Document`, `Prompt`,
  `Agent`, and `Configuration`.
- `Context` graphs that group related assets, computations, and statements.
- Local software signers with persistent decentralized identifiers.
- Explicit `Computation` builders and `integrity_compute()` for R functions.
- Local Integrity Manifest import and export.
- Optional `Service` integration for EQTY Governance Studio workflows.

These bindings let an R workflow identify the assets it consumed, record the
operations it performed, and connect them to the outputs it produced. The
package handles the R-to-Python setup and value conversion needed by common SDK
operations, allowing the workflow to remain in R while using the Python SDK's
data model and manifest format.

### Assets and content identifiers

Create an asset with `from_path()` when a file or directory is the artifact,
`from_object()` for an in-memory R value, or `from_cid()` when an existing CID
is authoritative. The resulting `$cid` changes when the content changes.

EQTY content identifiers use the
[IPFS CID format](https://specs.ipfs.tech/cid/). A CID is self-describing: it
encodes its version, content codec, hash algorithm, and hash digest. Using this
format does not upload the asset to IPFS or make it publicly available.

For a file registered with `from_path()`, you can verify its CID manually:

1. Copy the asset CID and remove the `urn:cid:` prefix, if present.
2. Paste the remaining value into the
   [IPFS CID Inspector](https://cid.ipfs.tech/).
3. Confirm that the decoded multihash algorithm is BLAKE3 and copy its
   hexadecimal digest.
4. Calculate the BLAKE3 digest of the same file bytes with a tool such as
   `b3sum`:

   ```bash
   b3sum path/to/file
   ```

5. Compare the hexadecimal output from `b3sum` with the digest shown by the
   CID Inspector. They should match when the file bytes are identical.

This direct comparison applies to file-content CIDs. Directories and in-memory
objects require the same serialization and hashing rules used by the SDK, so
hashing an individual file is not sufficient to reproduce their CIDs.

### Contexts and manifests

A `Context` defines a graph and manifest boundary. `Context$export()` writes
its statements and stored blobs to a JSON manifest. `Context$import_manifest()`
can load an existing graph into a later execution.

### Signers

Every generated statement is attributed to the active signer's DID.
`Signer$load_or_create()` creates the named local signer on its first run and
loads the same identity on later runs. By default, its persistent state is
stored under `.eqty_sdk/` in the working directory. Preserve and protect this
directory when the same signer identity must be used across runs, especially
in production environments.

### Computations

Use `Computation` to connect explicit input and output CIDs. Use
`integrity_compute()` when an R function performs the recorded operation; the
wrapper registers the function as a `Code` asset and records its execution.

## Important usage notes

- Setting `_store = TRUE` copies asset content into local SDK storage and the
  exported manifest. Do not use it for credentials, private keys, personal
  data, confidential records, or other information that must not be shared.
- Never hardcode credentials in source code that may be registered as a `Code`
  asset or embedded in a manifest. Read secrets at runtime with `Sys.getenv()`
  or from an approved secrets vault. Do not register `.Renviron`, vault
  responses, or resolved secret values as assets.
- The `.eqty_sdk/` directory contains local state and private signing keys.
  Preserve it when signer identity must remain stable, restrict access to it,
  and never commit or register it as an asset. Pass `custom_dir` to
  `integrity_init()` when this state must be stored elsewhere.
- Local manifest generation does not require Governance Studio credentials or
  a remote `Service`. For guidance on configuring Governance Studio or a remote
  service, contact the maintainers.

## Reference documentation

After installation, open the generated R reference with:

```r
help(package = "eqty.sdk.r")
```

- [CRAN package page](https://cran.r-project.org/package=eqty.sdk.r) — available
  after the first CRAN release
- [Latest Python SDK implementation documentation](https://eqtylab.github.io/integrity-py/latest/)
- [Development Python SDK implementation documentation](https://eqtylab.github.io/integrity-py/dev/)
- [R examples](https://github.com/eqtylab/integrity-r/tree/main/samples)

## Development and releases

Package documentation is maintained as roxygen comments in `package/R/*.R`.
Generated `package/man/*.Rd` files are intentionally not committed.

From the repository root, install `roxygen2` and run the release build:

```r
install.packages("roxygen2")
```

```bash
./build-package.sh
```

The script deletes stale reference files, regenerates them, builds the source
tarball under `dist/`, and runs `R CMD check --as-cran`. Use
`./build-package.sh --no-manual` on systems without TeX.

The GitHub package-check workflow runs manually. Pushing a matching version 
tag such runs the same build and attaches the source tarball to a GitHub Release. 
The generated `.Rd` files are included in that tarball.

## Security

Report suspected vulnerabilities according to the repository's
[security policy](https://github.com/eqtylab/integrity-r/security/policy).
