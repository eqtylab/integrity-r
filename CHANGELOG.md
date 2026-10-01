# Changelog

This file records notable changes to `eqty.sdk.r`.

## 0.9.2 - 2026-10-01

### Fixed

- Quoted software and package names in the DESCRIPTION title and description
  to meet CRAN formatting requirements.
- Added return-value documentation describing exported SDK proxy classes and
  their meaning, and clarified computation return values.
- Added runnable examples for SDK proxies, path resolution, and computation
  decorators. Explained the additional software required by the full computation
  example and added initialization and signer setup.

## 0.9.1 - 2026-09-21

### Fixed

- Deferred Python initialization until an exported SDK proxy is used so CRAN
  package checks do not require the `eqty-sdk` Python package.

## 0.9.0 - 2026-09-18

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
