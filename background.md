# Background

This document introduces the concepts behind `eqty.sdk.r`. For installation
and a complete quick start, see [`package/README.md`](package/README.md). For
sample commands, see [`samples/README.md`](samples/README.md). Exact R API
behavior is documented in `package/R/*.R`; the underlying SDK reference is in
the [versioned Python documentation](https://eqtylab.github.io/integrity-py/latest/).

## Purpose

`eqty.sdk.r` helps an R workflow build a verifiable record of its inputs,
outputs, computations, identities, and related artifacts. Each content-bearing
asset receives a content identifier, computations connect their inputs to their
outputs, and a context groups those records into an Integrity Manifest.

The package exposes Python-backed SDK objects through R names such as `Context`,
`Dataset`, `Model`, `Computation`, and `Signer`.

## Core concepts

### CID

A CID (Content Identifier) references content in distributed information
systems such as IPFS. It combines content addressing, cryptographic hashing,
and a self-describing binary format. A CID encodes its version, a multicodec
that identifies the content format, and a multihash that identifies the hash
algorithm and digest.

In the EQTY SDK, a CID is derived from a file, directory, or serialized object.
Changing that content produces a different identifier. Assets expose their CID
through `$cid`, and computations use CIDs to identify inputs and outputs.

### DID and UUID

A DID provides a durable identifier for the signer or entity associated with a
provenance statement. A UUID identifies something independently of its content.
Asset-oriented workflows usually use CIDs, while DIDs and UUIDs provide stable
identity where content addressing is not appropriate.

```r
signer_did <- DID$from_signer(signer, name = "Workflow signer")
stable_id <- UUID("123e4567-e89b-12d3-a456-426614174000")
```

### Context

A `Context` is the boundary for a related graph of assets, computations, and
statements. Parent and child contexts can organize several runs beneath a
project. Export writes the context's statements and retained blobs to a
manifest; import brings an existing manifest into a context.

```r
project <- Context$new("Example project")
run <- Context$with_parent(project)$new("Example run")
invisible(integrity_init(default_context = run))
```

### Assets

Assets represent tracked workflow inputs and outputs. Built-in categories
include data, documents, code, configuration, models, media, prompts, agents,
tools, validation artifacts, and other common workflow objects.

Choose the factory according to where the artifact exists:

- `from_path()` hashes a file or directory.
- `from_object()` serializes and hashes an in-memory value.
- `from_cid()` represents content with an authoritative existing CID.

```r
input <- Dataset$with_context(run)$from_path(
  "data/input.csv",
  name = "Input data"
)
```

The `_store` argument is separate from CID creation. `_store = TRUE` retains a
copy of the content so it can be included in an exported manifest.
`_store = FALSE` records the CID and lineage without retaining the original
content. A manifest containing stored blobs should be treated as containing a
copy of the source data; never embed secrets or sensitive records.

### Compute and Computation

`integrity_compute()` wraps an R function and records the function, its inputs,
and its outputs. Use `Computation` when the lineage relationship is explicit
but is not represented by an R function call.

```r
add_values <- integrity_compute(
  context = run,
  metadata = list(name = "Add values"),
  func = function(x, y) x + y
)
total <- add_values(10, 20)
```

An asset is the data or logic; a computation is the execution that consumed
inputs and produced outputs. `integrity_compute()` defaults to `_store = FALSE`
for the registered function source and hashed values.

### Signer

A `Signer` supplies the identity used to sign generated statements.
`Signer$load_or_create()` persists a named local signer so its DID remains
stable between runs.

```r
signer <- Signer$load_or_create(name = "example-signer")
invisible(integrity_set_active_signer(signer))
```

Local signer keys and SDK state are stored under `.eqty_sdk/` by default, or
under the `custom_dir` passed to `integrity_init()`. Protect and preserve that
directory when signer continuity matters. Never commit or register it as an
asset.

### Service

A `Service` connects a context to a remote Integrity Service or Governance
Studio-backed API. Workflows that only create local manifests do not need a
service or Governance Studio credentials.

## Where to go next

- [`package/README.md`](package/README.md) contains installation, dependency
  management, a complete quick start, and user-facing safety notes.
- [`samples/README.md`](samples/README.md) describes the runnable examples and
  their generated manifests.
- [`skills/eqty-sdk-r/SKILL.md`](skills/eqty-sdk-r/SKILL.md) contains portable
  instructions for coding agents.
- [`AGENTS.md`](AGENTS.md) contains repository-specific instrumentation and
  contribution rules.
