#!/usr/bin/env Rscript

# NAME
#     sample-all-nodes.R - Demonstrate all asset nodes in a simple AI workflow
#
# SYNOPSIS
#     Rscript sample-all-nodes.R
#
# DESCRIPTION
#     Records a four-step, fully local demonstration workflow:
#
#       - Ground a user's prompt with a mock knowledge source.
#       - Generate a mock response with an agent and model.
#       - Publish the response and a preview.
#       - Validate the response produced by publication.
#
#     The sample performs no model inference, network requests, or substantive
#     computation. Small synthetic values stand in for the artifacts that a
#     real workflow would produce. Together, the four steps use every built-in
#     asset category listed in the SDK documentation.
#
# OUTPUTS
#     output/manifest.json
#         Manifest JSON file containing the context's statements and blobs.
#
# DEPENDENCIES
#     R packages: eqty.sdk.r

library(eqty.sdk.r)

ctx <- Context$new("EQTY R SDK: simple AI response workflow")
invisible(integrity_init(default_context = ctx))

signer <- Signer$load_or_create(name = "eqty-r-all-nodes-demo")
invisible(integrity_set_active_signer(signer))

# The workflow uses small synthetic values for each asset category.

# Retrieve policy context
user_prompt <- Prompt$from_object(
  "What is the return policy for an unopened item?",
  name = "Customer question",
  description = "User prompt supplied to the assistant",
  `_store` = TRUE
)

system_prompt <- SystemPrompt$from_object(
  "Answer briefly using only the supplied policy context.",
  name = "Support assistant instructions",
  description = "System instructions governing the response",
  `_store` = TRUE
)

assistant_agent <- Agent$from_object(
  integrity_dict(role = "customer-support-assistant", mode = "demonstration"),
  name = "Support assistant",
  description = "Agent responsible for preparing the response",
  `_store` = TRUE
)

retrieval_tool <- Tool$from_object(
  integrity_dict(operation = "policy_lookup", implementation = "mock"),
  name = "Policy lookup tool",
  description = "Mock tool used to retrieve policy context",
  `_store` = TRUE
)

knowledge_database <- Database$from_object(
  integrity_dict(database = "support-policies", table = "return_policy"),
  name = "Support policy database",
  description = "Descriptor for the mock source of policy records",
  `_store` = TRUE
)

# This is a non-secret identity reference, not an API key or access token.
retrieval_credential <- Credential$from_object(
  integrity_dict(credential_ref = "local-demo-reader", scope = "policy:read"),
  name = "Policy reader credential reference",
  description = "Non-secret reference to the identity used for policy lookup",
  `_store` = TRUE
)

grounding_data <- Dataset$from_object(
  integrity_dict(
    policy_id = "RET-30",
    excerpt = "Unopened items may be returned within 30 days with a receipt."
  ),
  name = "Retrieved policy context",
  description = "Synthetic policy record selected for the customer question",
  `_store` = TRUE
)

invisible(
  Computation$new(
    name = "Retrieve policy context",
    description = "Uses the prompt and a mock policy lookup to select grounding data"
  )$add_input_cid(
    assistant_agent$cid
  )$add_input_cid(
    user_prompt$cid
  )$add_input_cid(
    retrieval_tool$cid
  )$add_input_cid(
    knowledge_database$cid
  )$add_input_cid(
    retrieval_credential$cid
  )$add_output_cid(
    grounding_data$cid
  )$finalize()
)

# Generate a response
language_model <- Model$from_object(
  integrity_dict(provider = "local-demo", model = "example-chat-model"),
  name = "Example chat model",
  description = "Mock language model used by the demonstration",
  `_store` = TRUE
)

model_configuration <- Configuration$from_object(
  integrity_dict(temperature = 0, max_output_tokens = 80L),
  name = "Response generation settings",
  description = "Configuration applied to the mock model invocation",
  `_store` = TRUE
)

answering_skill <- Skill$from_object(
  "Summarize supplied policy text as a concise customer-facing answer.",
  name = "Grounded answer skill",
  description = "Reusable instructions available to the support agent",
  `_store` = TRUE
)

response_code <- Code$from_object(
  "response <- model.generate(system_prompt, user_prompt, grounding_data)",
  name = "Response generation logic",
  description = "Illustrative pseudocode for the model invocation",
  `_store` = TRUE
)

model_runtime <- Binary$from_object(
  integrity_dict(runtime = "local-demo-runtime", version = "1.0"),
  name = "Model runtime",
  description = "Descriptor for the mock executable runtime",
  `_store` = TRUE
)

response_reasoning <- Reasoning$from_object(
  "The answer restates the supplied return window and receipt requirement.",
  name = "Response rationale",
  description = "Short non-sensitive explanation of how the response follows the policy",
  `_store` = TRUE
)

# Token represents usage information here; it is not an authentication token.
token_usage <- Token$from_object(
  integrity_dict(input_tokens = 34L, output_tokens = 16L),
  name = "Model token usage",
  description = "Synthetic token counts for the mock invocation",
  `_store` = TRUE
)

invisible(
  Computation$new(
    name = "Generate grounded response",
    description = "Uses the model, instructions, and policy to prepare the response rationale"
  )$add_input_cid(
    assistant_agent$cid
  )$add_input_cid(
    system_prompt$cid
  )$add_input_cid(
    user_prompt$cid
  )$add_input_cid(
    grounding_data$cid
  )$add_input_cid(
    language_model$cid
  )$add_input_cid(
    model_configuration$cid
  )$add_input_cid(
    answering_skill$cid
  )$add_input_cid(
    response_code$cid
  )$add_input_cid(
    model_runtime$cid
  )$add_output_cid(
    response_reasoning$cid
  )$add_output_cid(
    token_usage$cid
  )$finalize()
)

# Publish the response
draft_response <- Document$from_object(
  paste(
    "You can return an unopened item within 30 days",
    "when you have the receipt."
  ),
  name = "Draft customer response",
  description = "Synthetic response materialized by the publication stage",
  `_store` = TRUE
)

response_preview <- Media$from_object(
  integrity_dict(format = "text-preview", content = "30-day unopened return"),
  name = "Response preview",
  description = "Small presentation preview for the published response",
  `_store` = TRUE
)

publication_record <- Custom$with_context(
  ctx,
  asset_type = "PublicationRecord"
)$from_object(
  integrity_dict(channel = "local-demo", status = "published"),
  name = "Publication record",
  description = "Application-specific record of the mock publication",
  `_store` = TRUE
)

invisible(
  Computation$new(
    name = "Publish response",
    description = "Publishes the generated response with a preview and publication record"
  )$add_input_cid(
    response_reasoning$cid
  )$add_output_cid(
    draft_response$cid
  )$add_output_cid(
    response_preview$cid
  )$add_output_cid(
    publication_record$cid
  )$finalize()
)

# Validate the response produced by the publication stage. The validation
# result is deliberately a terminal output and is not consumed again.
response_guardrail <- Guardrail$from_object(
  integrity_dict(
    rule = "Response must agree with the supplied policy",
    action_on_failure = "mark_validation_failed"
  ),
  name = "Grounding guardrail",
  description = "Acceptance rule applied to the draft response",
  `_store` = TRUE
)

quality_benchmark <- Benchmark$from_object(
  integrity_dict(checks = c("policy_consistency", "conciseness")),
  name = "Response quality checks",
  description = "Simple evaluation protocol for the demonstration",
  `_store` = TRUE
)

response_certificate <- Certificate$from_object(
  integrity_dict(
    subject = "Local response validator",
    assertion = "Authorized to validate demonstration responses"
  ),
  name = "Response validation certificate",
  description = "Synthetic certificate presented as an input to response validation",
  `_store` = TRUE
)

validation_result <- BenchmarkResult$from_object(
  integrity_dict(status = "passed", score = 1),
  name = "Response validation result",
  description = "Synthetic result showing that the response passed the checks",
  `_store` = TRUE
)

invisible(
  Computation$new(
    name = "Validate response",
    description = "Checks the response against its source policy and quality rules"
  )$add_input_cid(
    draft_response$cid
  )$add_input_cid(
    grounding_data$cid
  )$add_input_cid(
    response_guardrail$cid
  )$add_input_cid(
    quality_benchmark$cid
  )$add_input_cid(
    response_certificate$cid
  )$add_output_cid(
    validation_result$cid
  )$finalize()
)

manifest_path <- "output/manifest.json"
invisible(ctx$export(integrity_path(manifest_path)))

cat("Recorded a four-step workflow using every built-in asset category.\n")
cat("Manifest successfully generated and exported to output/manifest.json.\n")
