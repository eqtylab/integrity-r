# NAME
#     sample-register.R - Register basic lineage
#
# SYNOPSIS
#     Rscript sample-register.R
#
# DESCRIPTION
#     Creates Code and Document assets, adds their CIDs to a Computation as its
#     input and output, finalizes the computation, and exports the context's
#     statements and blobs to a manifest JSON file.
#
#     This example uses explicit Context and Computation wiring with a local
#     signer.
#
# ARGUMENTS
#     None.
#
# DEPENDENCIES
#     R packages: eqty.sdk.r
library(eqty.sdk.r)

ctx <- Context$new("Basic example")

invisible(integrity_init(default_context = ctx))
signer <- Signer$load_or_create(name = "eqty-r-sample")
invisible(integrity_set_active_signer(signer))

# Create the Code asset used as the computation input.
in_obj <- integrity_dict(value = "input")
d_code <- Code$from_object(
  in_obj,
  name = "Input Data",
  description = "Description Input",
  `_store` = TRUE
)

# Create the Document asset used as the computation output.
out_obj <- integrity_dict(value = "out")
d_output <- Document$from_object(
  out_obj,
  name = "Output Data",
  description = "Description Output",
  `_store` = TRUE
)

# Add the input and output CIDs, then create the computation and metadata statements.
computation <- Computation$new(
  name = "Compute",
  description = "Compute Description"
)$add_input_cid(
  d_code$cid
)$add_output_cid(
  d_output$cid
)$finalize()

# Export the context's statements and blobs to a manifest JSON file.
manifest_path <- integrity_path("output/manifest.json")
invisible(ctx$export(manifest_path))

cat("Manifest successfully generated and exported to output/manifest.json.\n")
