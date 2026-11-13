# Shared model options. ellmer reads API keys from the environment.
qc_llm_config <- function(provider = "gemini", model = NULL, base_url = NULL) {
  provider <- match.arg(provider, c("gemini", "claude"))
  if (is.null(model)) {
    model <- switch(provider,
      gemini = "gemini-3.8-flash",
      claude = "claude-sonnet-5-5"
    )
  }
  if (!nzchar(trimws(model))) stop("Model must not be empty.", call. = FALSE)
  # URLs are recorded in lineage; authentication belongs in environment variables.
  if (!is.null(base_url) && !grepl("^https?://[^@/?#[:space:]]+(/[^?#[:space:]]*)?$", base_url)) {
    stop("Base URL must be HTTP(S), without credentials, query parameters, or fragments.", call. = FALSE)
  }
  # Allow enough output for a complete derivation program.
  list(provider = provider, model = model, base_url = base_url, max_tokens = 16384L)
}

qc_llm_options <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (any(args %in% c("--help", "-h"))) {
    cat("Options: --provider gemini|claude --model MODEL --base-url URL\n",
        "Use --option value. Default provider: gemini.\n",
        "Credentials: GOOGLE_API_KEY (Gemini) or ANTHROPIC_API_KEY (Claude).\n", sep = "")
    return(NULL)
  }
  keys <- c("--provider" = "provider", "--model" = "model", "--base-url" = "base_url")
  if (length(args) %% 2L != 0L) {
    stop("Expected --option value pairs. See --help.", call. = FALSE)
  }
  options <- list()
  for (pair in seq_len(length(args) / 2L)) {
    i <- 2L * pair - 1L
    key <- args[[i]]
    value <- args[[i + 1L]]
    if (!key %in% names(keys) || startsWith(value, "--") || !nzchar(trimws(value))) {
      stop("Expected --provider, --model, or --base-url followed by a value. See --help.", call. = FALSE)
    }
    options[[keys[[key]]]] <- value
  }
  # The workflow resolves defaults and records the output limit on its Agent.
  options
}

qc_llm_chat <- function(config, system_prompt) {
  factory <- switch(config$provider,
    gemini = ellmer::chat_google_gemini,
    claude = ellmer::chat_anthropic
  )
  args <- list(system_prompt = system_prompt, model = config$model, echo = "none",
               params = ellmer::params(max_tokens = config$max_tokens))
  if (!is.null(config$base_url)) args$base_url <- config$base_url
  do.call(factory, args)
}
