# eqty.sdk.r 0.9.1

- Defer Python initialization until an exported SDK proxy is used, allowing
  package metadata and documentation checks to run without requiring the
  `eqty-sdk` Python package.

# eqty.sdk.r 0.9.0

## Initial release

- Added R bindings for the Python-backed EQTY SDK asset, context, computation,
  signer, identifier, service, and verification APIs.
- Added helpers for initialization, signer configuration, Python paths and
  dictionaries, path resolution, and instrumented R functions.
- Added automatic provisioning of `eqty-sdk>=2.4.1` through reticulate's
  managed Python environment.
- Added local manifest examples ranging from basic lineage to multi-stage agent
  workflows and manifest merging.
