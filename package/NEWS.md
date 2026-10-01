# eqty.sdk.r 0.9.2

- Quote software and package names in the DESCRIPTION title and description
  to meet CRAN formatting requirements.
- Document the classes and meaning of exported SDK proxies and clarify
  computation return values.
- Add runnable examples for SDK proxies, path resolution, and computation
  decorators; document the additional software required by the full computation
  example and include initialization and signer setup.

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
