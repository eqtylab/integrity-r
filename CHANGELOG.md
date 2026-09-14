# Changelog

This file records notable changes to `eqty.sdk.r`.

## 0.9.0

Initial release.

### Added

- R access to the Python-backed EQTY SDK types for assets, contexts,
  computations, signers, identifiers, services, and verification.
- R helpers for SDK initialization, active signer configuration, Python paths,
  Python dictionaries, path resolution, and wrapped R computations.
- Examples covering content-addressed assets, signed lineage,
  parent and child context graphs, wrapped computations, validation evidence,
  agent workflows, and manifest merging across separate executions.
- Package documentation and instructions for instrumenting R workflows.
- CRAN installation guidance, versioned Python SDK documentation links, and a
  corrected sample guide for the initial package release.
- A package build script and CI check that regenerate roxygen
  documentation before creating the CRAN source tarball.
