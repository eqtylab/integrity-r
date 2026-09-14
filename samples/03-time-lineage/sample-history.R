#!/usr/bin/env Rscript

# NAME
#     sample-history.R - Build a branching Roman history timeline
#
# SYNOPSIS
#     Rscript sample-history.R
#
# DESCRIPTION
#     Creates two simple lineage branches: the final years of the Roman
#     Republic and the rise of Julius Caesar. The branches converge at the
#     assassination of Caesar on the Ides of March.
#
#     The example demonstrates parent-child contexts, computation metadata,
#     multiple input CIDs, a local signer, and context export.
#
# OUTPUTS
#     output/manifest.json
#
# DEPENDENCIES
#     R packages: eqty.sdk.r

library(eqty.sdk.r)

root_context <- Context$new("Roman history timeline")

ctx <- Context$with_parent(root_context)$new(
  "Roman Republic and Julius Caesar"
)

invisible(integrity_init(default_context = ctx))

signer <- Signer$load_or_create(name = "eqty-r-history")
invisible(integrity_set_active_signer(signer))

# Roman Republic branch
roman_republic <- Dataset$from_object(
  integrity_dict(name = "Roman Republic"),
  name = "Roman Republic",
  description = "The republican government of ancient Rome before Caesar's dictatorship",
  `_store` = TRUE
)

civil_war <- Dataset$from_object(
  integrity_dict(name = "Caesar's Civil War"),
  name = "Caesar's Civil War",
  description = "Conflict between Caesar's forces and the senatorial faction led by Pompey",
  `_store` = TRUE
)

invisible(
  Computation$new(
    name = "Crossing the Rubicon",
    description = "Caesar crossed the Rubicon with the Thirteenth Legion, beginning civil war",
    year = "49 BCE"
  )$add_input_cid(
    roman_republic$cid
  )$add_output_cid(
    civil_war$cid
  )$finalize()
)

caesars_dictatorship <- Dataset$from_object(
  integrity_dict(name = "Caesar's dictatorship"),
  name = "Caesar's dictatorship",
  description = "Caesar held dominant political and military power after defeating his rivals",
  `_store` = TRUE
)

invisible(
  Computation$new(
    name = "Victory in the civil war",
    description = "Caesar defeated the remaining Pompeian forces and returned to Rome",
    year = "45 BCE"
  )$add_input_cid(
    civil_war$cid
  )$add_output_cid(
    caesars_dictatorship$cid
  )$finalize()
)

# Julius Caesar branch
caesars_family <- Dataset$from_object(
  integrity_dict(name = "Gaius Julius Caesar and Aurelia"),
  name = "Caesar's family",
  description = "The parents of Gaius Julius Caesar",
  `_store` = TRUE
)

young_caesar <- Dataset$from_object(
  integrity_dict(name = "Young Julius Caesar"),
  name = "Young Julius Caesar",
  description = "Julius Caesar before holding Rome's highest political offices",
  `_store` = TRUE
)

invisible(
  Computation$new(
    name = "Birth of Julius Caesar",
    description = "Julius Caesar was born into the patrician Julian family",
    year = "100 BCE"
  )$add_input_cid(
    caesars_family$cid
  )$add_output_cid(
    young_caesar$cid
  )$finalize()
)

caesar_as_consul <- Dataset$from_object(
  integrity_dict(name = "Julius Caesar as consul"),
  name = "Julius Caesar as consul",
  description = "Caesar during his first consulship in Rome",
  `_store` = TRUE
)

invisible(
  Computation$new(
    name = "Election as consul",
    description = "Caesar became one of the Roman Republic's two consuls",
    year = "59 BCE"
  )$add_input_cid(
    young_caesar$cid
  )$add_output_cid(
    caesar_as_consul$cid
  )$finalize()
)

caesar_as_general <- Dataset$from_object(
  integrity_dict(name = "Caesar after the Gallic Wars"),
  name = "Caesar as victorious general",
  description = "Caesar returned from Gaul with military prestige and loyal legions",
  `_store` = TRUE
)

invisible(
  Computation$new(
    name = "Gallic Wars",
    description = "Caesar's campaigns in Gaul expanded Roman territory and his political power",
    year = "58-50 BCE"
  )$add_input_cid(
    caesar_as_consul$cid
  )$add_output_cid(
    caesar_as_general$cid
  )$finalize()
)

caesar_as_dictator <- Dataset$from_object(
  integrity_dict(name = "Julius Caesar as dictator for life"),
  name = "Julius Caesar as dictator",
  description = "Caesar after receiving the title dictator perpetuo",
  `_store` = TRUE
)

invisible(
  Computation$new(
    name = "Appointment as dictator for life",
    description = "The Senate granted Caesar the title dictator perpetuo",
    year = "44 BCE"
  )$add_input_cid(
    caesar_as_general$cid
  )$add_input_cid(
    caesars_dictatorship$cid
  )$add_output_cid(
    caesar_as_dictator$cid
  )$finalize()
)

# The two historical branches converge at the Ides of March.
senate_conspirators <- Dataset$from_object(
  integrity_dict(name = "Roman senators in the conspiracy"),
  name = "Senate conspirators",
  description = "A group of senators who opposed Caesar's concentration of power",
  `_store` = TRUE
)

ides_of_march <- Dataset$from_object(
  integrity_dict(name = "Assassination of Julius Caesar"),
  name = "Ides of March",
  description = "Julius Caesar was assassinated during a Senate meeting in Rome",
  `_store` = TRUE
)

invisible(
  Computation$new(
    name = "Assassination of Julius Caesar",
    description = "The conspirators assassinated Caesar at the Theatre of Pompey",
    date = "15 March 44 BCE"
  )$add_input_cid(
    caesars_dictatorship$cid
  )$add_input_cid(
    caesar_as_dictator$cid
  )$add_input_cid(
    senate_conspirators$cid
  )$add_output_cid(
    ides_of_march$cid
  )$finalize()
)

manifest_path <- integrity_path("output/manifest.json")
invisible(ctx$export(manifest_path))

cat("Manifest successfully generated and exported to output/manifest.json.\n")
