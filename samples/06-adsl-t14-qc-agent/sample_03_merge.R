#!/usr/bin/env Rscript

# Merge EQTY manifests
#
# Usage:
#     Rscript sample_03_merge.R <file1.json> <file2.json> ...
#
# Imports the statements and blobs from each readable manifest into a new local
# context and exports the combined lineage to output/manifest.json.

library(eqty.sdk.r)

main <- function() {
  manifest_paths <- commandArgs(trailingOnly = TRUE)

  if (length(manifest_paths) == 0L) {
    cat(
      "Usage: Rscript sample_03_merge.R <file1.json> <file2.json> ...\n",
      file = stderr()
    )
    quit(status = 1L)
  }

  invisible(integrity_init())
  merged_context <- Context$new("merged-manifests")

  cat(sprintf("Processing %d manifest files...\n", length(manifest_paths)))
  imported_count <- 0L

  for (path in manifest_paths) {
    if (!file.exists(path)) {
      cat(sprintf("Manifest not found, skipping: %s\n", path), file = stderr())
      next
    }

    imported <- tryCatch(
      {
        invisible(merged_context$import_manifest(integrity_path(path)))
        TRUE
      },
      error = function(error) {
        cat(
          sprintf("Error importing %s: %s\n", path, conditionMessage(error)),
          file = stderr()
        )
        FALSE
      }
    )

    if (imported) {
      cat(sprintf("Successfully imported: %s\n", path))
      imported_count <- imported_count + 1L
    }
  }

  if (imported_count == 0L) {
    cat("Error: No valid manifests were imported. Export cancelled.\n", file = stderr())
    quit(status = 1L)
  }

  invisible(merged_context$export(integrity_path("output/manifest.json")))
  cat(sprintf("Combined lineage from %d manifest files.\n", imported_count))
  cat("Manifest successfully generated and exported to output/manifest.json.\n")
}

if (sys.nframe() == 0L) {
  main()
}
