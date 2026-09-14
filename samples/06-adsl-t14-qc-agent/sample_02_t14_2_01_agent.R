#!/usr/bin/env Rscript

# Live T14.2.01 QC demonstration
#
# Workflow: T14.2.01 specification + independently generated ADSL from the
# upstream ADSL QC agent -> LLM generates R -> local R runs it -> independent
# T14.2.01 -> comparison with the production table -> pass/fail report.
# Subject-level ADSL and the production table are never sent to the LLM.

library(eqty.sdk.r)

# ---- EQTY SDK configuration -------------------------------------------------
# SDK initialization is deferred until the live workflow runs. This keeps the
# deterministic comparison helpers usable when the script is sourced.

# ---- EQTY SDK helpers -------------------------------------------------------

t14_qc_integrity_init <- function() {
  ctx <- Context$new(
    "LZZT_001 — Live T14.2.01 Independent LLM QC"
  )
  invisible(integrity_init(default_context = ctx))

  signer <- Signer$load_or_create(name = "eqty-r-t14-qc")
  invisible(integrity_set_active_signer(signer))
  signer_did <- DID$from_signer(
    signer,
    name = "Bob",
    description = "Local signer"
  )

  list(ctx = ctx, signer_did = signer_did)
}

# ---- General helpers --------------------------------------------------------

t14_qc_root <- function() {
  configured <- Sys.getenv("RWE_PROJECT_ROOT", unset = "")
  if (nzchar(configured)) {
    return(normalizePath(configured, mustWork = FALSE))
  }

  normalizePath(getwd(), mustWork = FALSE)
}

t14_qc_resolve <- function(path, root) {
  if (grepl("^(/|[A-Za-z]:[/\\\\])", path)) {
    return(path)
  }

  file.path(root, path)
}

t14_qc_log <- function(title, text) {
  cat("\n", strrep("=", 78), "\n", title, "\n", strrep("-", 78), "\n", text, "\n", sep = "")
}

# ---- Deterministic QC comparison -------------------------------------------

t14_qc_required_columns <- function() {
  c("Characteristic", "Statistic", "Value")
}

t14_qc_required_adsl_columns <- function() {
  c(
    "USUBJID", "ITTFL", "AGE", "AGEGR1", "RACE", "SEX",
    "HEIGHTBL", "WEIGHTBL", "BMIBL", "MMSETOT"
  )
}

t14_qc_read_adsl <- function(path) {
  if (!file.exists(path)) {
    stop("Independent ADSL not found: ", path, call. = FALSE)
  }

  adsl <- utils::read.csv(
    path,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )
  missing_columns <- setdiff(t14_qc_required_adsl_columns(), names(adsl))
  if (length(missing_columns)) {
    stop(
      "Independent ADSL is missing T14.2.01 input column(s): ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  duplicate_ids <- unique(adsl$USUBJID[duplicated(adsl$USUBJID)])
  if (length(duplicate_ids)) {
    stop(
      "Independent ADSL has duplicate USUBJID values: ",
      paste(duplicate_ids, collapse = ", "),
      call. = FALSE
    )
  }
  if (!any(adsl$ITTFL == "Y", na.rm = TRUE)) {
    stop("Independent ADSL contains no ITTFL == 'Y' subjects.", call. = FALSE)
  }

  adsl
}

t14_qc_validate_upstream_adsl <- function(report_path) {
  if (!file.exists(report_path)) {
    stop("Upstream ADSL QC report not found: ", report_path, call. = FALSE)
  }

  report <- utils::read.csv(report_path, stringsAsFactors = FALSE)
  required_report_columns <- c("variable", "is_critical", "n_mismatch")
  missing_report_columns <- setdiff(required_report_columns, names(report))
  if (length(missing_report_columns)) {
    stop(
      "Upstream ADSL QC report is missing column(s): ",
      paste(missing_report_columns, collapse = ", "),
      call. = FALSE
    )
  }

  required_variables <- t14_qc_required_adsl_columns()
  missing_variables <- setdiff(required_variables, report$variable)
  if (length(missing_variables)) {
    stop(
      "Upstream ADSL QC report did not assess T14.2.01 input variable(s): ",
      paste(missing_variables, collapse = ", "),
      call. = FALSE
    )
  }

  # T14.2.01 depends on these fields even when they are noncritical for the
  # broader ADSL QC. Any discrepancy in a table input blocks this workflow.
  n_mismatch <- suppressWarnings(as.numeric(report$n_mismatch))
  is_critical <- as.logical(report$is_critical)
  if (anyNA(n_mismatch) || anyNA(is_critical)) {
    stop("Upstream ADSL QC report contains invalid QC values.", call. = FALSE)
  }

  relevant_failures <- report$variable %in% required_variables & n_mismatch > 0L
  critical_failures <- is_critical & n_mismatch > 0L
  failures <- relevant_failures | critical_failures
  if (any(failures)) {
    stop(
      "Upstream ADSL is not approved for T14.2.01; QC mismatch(es): ",
      paste(unique(report$variable[failures]), collapse = ", "),
      ". See ", report_path, ".",
      call. = FALSE
    )
  }

  invisible(report)
}

t14_qc_read <- function(path, label) {
  if (!file.exists(path)) {
    stop(label, " not found: ", path, call. = FALSE)
  }

  data <- utils::read.csv(
    path,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    na.strings = "NA"
  )
  required <- t14_qc_required_columns()

  if (!identical(names(data), required)) {
    stop(
      label, " must contain exactly these columns in order: ",
      paste(required, collapse = ", "), ". Found: ",
      paste(names(data), collapse = ", "), ".",
      call. = FALSE
    )
  }

  data
}

t14_qc_mismatch <- function(left, right) {
  left <- as.character(left)
  right <- as.character(right)
  !(is.na(left) & is.na(right)) & (is.na(left) | is.na(right) | left != right)
}

t14_qc_normalize_categorical_rows <- function(data) {
  # The specification fixes the order of table sections but does not prescribe
  # the order of observed levels within a categorical section. Sort only those
  # level rows so equivalent tables compare successfully regardless of their
  # input-data order.
  normalized <- list()
  output_index <- 1L
  row_index <- 1L

  while (row_index <= nrow(data)) {
    row <- data[row_index, , drop = FALSE]
    is_categorical_header <-
      !is.na(row$Characteristic) && nzchar(row$Characteristic) &&
      (is.na(row$Statistic) || !nzchar(row$Statistic)) &&
      (is.na(row$Value) || !nzchar(row$Value))

    normalized[[output_index]] <- row
    output_index <- output_index + 1L
    row_index <- row_index + 1L

    if (!is_categorical_header) {
      next
    }

    level_start <- row_index
    while (
      row_index <= nrow(data) &&
      !is.na(data$Statistic[row_index]) &&
      data$Statistic[row_index] == "n"
    ) {
      row_index <- row_index + 1L
    }

    if (row_index > level_start) {
      levels <- data[level_start:(row_index - 1L), , drop = FALSE]
      levels <- levels[order(levels$Characteristic), , drop = FALSE]
      normalized[[output_index]] <- levels
      output_index <- output_index + 1L
    }
  }

  result <- do.call(rbind, normalized)
  rownames(result) <- NULL
  result
}

t14_qc_compare <- function(production_path, independent_path, report_path) {
  production <- t14_qc_read(production_path, "Production T14.2.01")
  independent <- t14_qc_read(independent_path, "Independent T14.2.01")
  required <- t14_qc_required_columns()

  production_rows <- nrow(production)
  independent_rows <- nrow(independent)
  comparison_rows <- max(production_rows, independent_rows)

  production <- t14_qc_normalize_categorical_rows(production)
  independent <- t14_qc_normalize_categorical_rows(independent)

  # After normalizing categorical levels, compare by row position. This avoids
  # an ambiguous join on repeated blank Characteristic/Statistic pairs such as
  # "" + "Median" in continuous sections.
  pad_column <- function(values, length_out) {
    values <- as.character(values)
    length(values) <- length_out
    values
  }

  column_rows <- lapply(required, function(column) {
    mismatches <- t14_qc_mismatch(
      pad_column(production[[column]], comparison_rows),
      pad_column(independent[[column]], comparison_rows)
    )
    n_mismatch <- sum(mismatches)

    data.frame(
      item = column,
      is_critical = TRUE,
      n_compared = comparison_rows,
      n_mismatch = n_mismatch,
      match_rate = if (comparison_rows == 0L) 1 else 1 - n_mismatch / comparison_rows,
      stringsAsFactors = FALSE
    )
  })

  row_count_row <- data.frame(
    item = "ROW_COUNT",
    is_critical = TRUE,
    n_compared = production_rows,
    n_mismatch = abs(production_rows - independent_rows),
    match_rate = as.numeric(production_rows == independent_rows),
    stringsAsFactors = FALSE
  )
  report <- do.call(rbind, c(list(row_count_row), column_rows))

  utils::write.csv(report, report_path, row.names = FALSE, na = "")

  report
}

run_t14_2_01_qc <- function(
  production_path = file.path("data", "production", "T14_2_01.csv"),
  independent_path = file.path("data", "independent", "t14_2_01_demo_llm.csv"),
  report_path = file.path("output", "t14_2_01_demo_qc_discrepancy_report.csv"),
  root = t14_qc_root()
) {
  production_path <- t14_qc_resolve(production_path, root)
  independent_path <- t14_qc_resolve(independent_path, root)
  report_path <- t14_qc_resolve(report_path, root)
  report <- t14_qc_compare(production_path, independent_path, report_path)

  failed <- report$is_critical & report$n_mismatch > 0L
  if (any(failed)) {
    stop(
      "T14.2.01 QC failed for critical item(s): ",
      paste(report$item[failed], collapse = ", "),
      ". See ", report_path, ".",
      call. = FALSE
    )
  }

  invisible(list(
    status = "PASSED",
    report = report,
    production_path = production_path,
    output_path = independent_path,
    report_path = report_path
  ))
}

# ---- LLM code generation and local execution -------------------------------
# The LLM receives derivation instructions and concrete file names. It returns
# R source code, which is saved and run locally against the real project ADSL.

t14_qc_extract_r_code <- function(response) {
  response <- trimws(as.character(response))
  match <- regexec("```[rR]?[[:space:]]*([\\s\\S]*?)```", response, perl = TRUE)
  parts <- regmatches(response, match)[[1L]]
  code <- if (length(parts) >= 2L) trimws(parts[[2L]]) else response

  if (!nzchar(code)) {
    stop("LLM returned no R code.", call. = FALSE)
  }

  code
}

t14_qc_validate_generated_code <- function(
  code,
  required_paths = character(),
  forbidden_paths = character()
) {
  parsed <- tryCatch(parse(text = code), error = function(error) {
    stop("Generated R code does not parse: ", conditionMessage(error), call. = FALSE)
  })

  blocked_calls <- c(
    "system", "system2", "shell", "pipe", "download.file", "url",
    "socketConnection", "unlink", "file.remove", "file.rename", "setwd",
    "Sys.setenv", "source", "dyn.load", "install.packages"
  )
  parsed_text <- paste(deparse(parsed), collapse = "\n")
  used <- blocked_calls[vapply(blocked_calls, function(name) {
    grepl(
      paste0("(^|[^[:alnum:]_.])", name, "[[:space:]]*\\("),
      parsed_text,
      perl = TRUE
    )
  }, logical(1L))]

  if (length(used)) {
    stop("Generated R code uses blocked call(s): ", paste(used, collapse = ", "), call. = FALSE)
  }

  missing_paths <- required_paths[!vapply(
    required_paths,
    function(path) grepl(path, code, fixed = TRUE),
    logical(1L)
  )]
  if (length(missing_paths)) {
    stop(
      "Generated R code does not use required path(s): ",
      paste(missing_paths, collapse = ", "),
      call. = FALSE
    )
  }

  forbidden_paths <- forbidden_paths[nzchar(forbidden_paths)]
  accessed_forbidden_paths <- forbidden_paths[vapply(
    forbidden_paths,
    function(path) grepl(path, code, fixed = TRUE),
    logical(1L)
  )]
  if (length(accessed_forbidden_paths)) {
    stop(
      "Generated R code references forbidden production path(s): ",
      paste(accessed_forbidden_paths, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(parsed)
}

t14_qc_asset_value <- function(asset) {
  value <- asset$value
  if (reticulate::is_py_object(value)) {
    return(reticulate::py_to_r(value))
  }
  value
}

t14_qc_request_model <- function(agent_asset, system_prompt_asset, user_prompt_asset) {
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("Package 'ellmer' is required. Install it with install.packages('ellmer').", call. = FALSE)
  }

  agent_config <- t14_qc_asset_value(agent_asset)
  system_prompt <- as.character(t14_qc_asset_value(system_prompt_asset))
  user_prompt <- as.character(t14_qc_asset_value(user_prompt_asset))
  model <- agent_config$model
  if (is.null(model) || !nzchar(as.character(model))) {
    stop("The T14.2.01 code-generation Agent does not define a model.", call. = FALSE)
  }
  model <- as.character(model)

  chat <- ellmer::chat_google_gemini(
    system_prompt = system_prompt,
    model = model,
    echo = "none"
  )

  response_text <- as.character(chat$chat(user_prompt))
  assistant_turn <- chat$last_turn()
  raw_response <- assistant_turn@json
  if (is.null(raw_response) || length(raw_response) == 0L) {
    stop("LLM raw provider response was not returned.", call. = FALSE)
  }

  usage <- chat$get_tokens()
  if (nrow(usage) == 0L) {
    stop("LLM token usage was not returned.", call. = FALSE)
  }
  latest_usage <- usage[nrow(usage), , drop = FALSE]

  token_usage <- integrity_dict(
    input = as.numeric(latest_usage$input),
    output = as.numeric(latest_usage$output),
    cached_input = as.numeric(latest_usage$cached_input)
  )
  response_record <- integrity_dict(
    provider_response = raw_response,
    response_text = response_text,
    token_usage = token_usage,
    role = as.character(assistant_turn@role),
    cost = as.numeric(assistant_turn@cost),
    duration = as.numeric(assistant_turn@duration)
  )

  Document$from_object(
    response_record,
    name = "Raw T14.2.01 provider response",
    description = "Complete unprocessed provider response and response metadata retained by ellmer",
    `_store` = TRUE
  )
}

t14_qc_project_root <- function() {
  args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  candidates <- c(getwd(), file.path(getwd(), ".."))
  if (length(args)) {
    script_path <- sub("^--file=", "", args[[1L]])
    candidates <- c(candidates, file.path(dirname(script_path), ".."))
  }
  candidates <- unique(candidates)

  found <- vapply(
    candidates,
    function(path) file.exists(file.path(path, "data", "spec", "t14_2_01_spec.txt")),
    logical(1L)
  )
  if (!any(found)) {
    stop("Run from the 06-adsl-t14-qc-agent example directory.", call. = FALSE)
  }

  normalizePath(candidates[[which(found)[[1L]]]], mustWork = TRUE)
}

run_live_t14_2_01_qc_demo <- function(
  spec_path = file.path("data", "spec", "t14_2_01_spec.txt"),
  independent_adsl_path = file.path("output", "adsl_llm.csv"),
  adsl_qc_report_path = file.path("output", "adsl_qc_discrepancy_report.csv"),
  production_path = file.path("data", "production", "T14_2_01.csv"),
  independent_path = file.path("output", "t14_2_01_demo_llm.csv"),
  generated_code_path = file.path("output", "t14_2_01_demo_generated.R"),
  model = Sys.getenv("GEMINI_MODEL", unset = "gemini-3.8-flash"),
  root = t14_qc_project_root(),
  verbose = TRUE
) {
  # STEP 1 — Resolve and verify the real project inputs.
  root <- normalizePath(root, mustWork = TRUE)
  normalize <- function(path) normalizePath(t14_qc_resolve(path, root), mustWork = FALSE)
  spec_path <- normalize(spec_path)
  independent_adsl_path <- normalize(independent_adsl_path)
  adsl_qc_report_path <- normalize(adsl_qc_report_path)
  production_path <- normalize(production_path)
  independent_path <- normalize(independent_path)
  generated_code_path <- normalize(generated_code_path)

  if (!file.exists(spec_path)) {
    stop("T14.2.01 specification not found: ", spec_path, call. = FALSE)
  }
  if (!file.exists(production_path)) {
    stop("Production T14.2.01 not found: ", production_path, call. = FALSE)
  }
  # The table can run only after the upstream independent ADSL exists and its
  # QC report confirms every field used by T14.2.01 matches production ADSL.
  invisible(t14_qc_read_adsl(independent_adsl_path))
  invisible(t14_qc_validate_upstream_adsl(adsl_qc_report_path))
  invisible(t14_qc_read(production_path, "Production T14.2.01"))

  report_path <- file.path(root, "output", "t14_2_01_demo_qc_discrepancy_report.csv")
  manifest_path <- "output/manifest-t14-2-01.json"

  # STEP 2 — Register the T14.2.01 specification, shared ADSL and QC evidence,
  # and production table in a separate context. integrity_compute records the
  # executable stages.
  sdk <- t14_qc_integrity_init()

  d_spec <- Document$with_context(sdk$ctx)$from_path(
    spec_path,
    name = basename(spec_path),
    description = "Independent T14.2.01 derivation specification supplied to the LLM",
    `_store` = TRUE
  )
  d_adsl <- Dataset$with_context(sdk$ctx)$from_path(
    independent_adsl_path,
    name = basename(independent_adsl_path),
    description = "Independent ADSL produced by the upstream ADSL QC agent and read locally by the T14.2.01 program",
    `_store` = TRUE
  )
  d_adsl_qc_report <- Dataset$with_context(sdk$ctx)$from_path(
    adsl_qc_report_path,
    name = basename(adsl_qc_report_path),
    description = "Upstream ADSL discrepancy report used to approve T14.2.01 source variables",
    `_store` = TRUE
  )
  d_production <- Dataset$with_context(sdk$ctx)$from_path(
    production_path,
    name = basename(production_path),
    description = "Validated production T14.2.01 used only as the deterministic QC reference",
    `_store` = TRUE
  )
  registered_adsl_path <- as.character(integrity_resolve_path(d_adsl))

  # STEP 3 — Create the user prompt from the registered T14.2.01 specification
  # before contacting the agent. The system prompt is configured independently
  # and is not an output of this computation.
  system_prompt <- paste(
    "You are an independent clinical programmer.",
    "Return only one complete executable R program; no explanation, Markdown, CSV, or data values.",
    "Use only base R and utils::read.csv / utils::write.csv.",
    "Your program must read the supplied independent ADSL CSV at runtime; never embed or invent input rows.",
    "Do not call the operating system, network, package installation, production ADSL, production program, or production table."
  )
  d_agent <- Agent$with_context(sdk$ctx)$from_object(
    integrity_dict(
      package = "ellmer",
      provider = "Google Gemini",
      model = model
    ),
    name = "T14.2.01 code-generation agent",
    description = "Ellmer Gemini agent configured to generate the independent T14.2.01 R program"
  )
  d_system_prompt <- SystemPrompt$with_context(sdk$ctx)$from_object(
    system_prompt,
    name = "T14.2.01 code-generation system prompt",
    description = "System instructions supplied to the model",
    `_store` = TRUE
  )
  create_t14_user_prompt <- integrity_compute(
    context = sdk$ctx,
    metadata = list(
      "name" = "Create T14.2.01 Code-generation User Prompt",
      "description" = "Creates the user prompt from the T14.2.01 specification",
      "author" = "Eqty Lab"
    ),
    `_store` = TRUE,
    func = function(spec_document) {
      resolved_spec_path <- as.character(integrity_resolve_path(spec_document))
      prompt_text <- paste(
        "Derive Table 14.2.01 exactly from this specification:",
        paste(readLines(resolved_spec_path, warn = FALSE), collapse = "\n"),
        "",
        "Read only this registered independent ADSL CSV produced by the upstream ADSL QC workflow:",
        registered_adsl_path,
        "",
        "Write the derived CSV to:",
        independent_path,
        sep = "\n"
      )

      Prompt$with_context(sdk$ctx)$from_object(
        prompt_text,
        name = "T14.2.01 code-generation user prompt",
        description = "User request supplied to the model",
        `_store` = TRUE
      )
    }
  )
  d_user_prompt <- create_t14_user_prompt(d_spec)
  user_prompt <- as.character(t14_qc_asset_value(d_user_prompt))

  if (isTRUE(verbose)) {
    t14_qc_log("LIVE T14.2.01 QC — CONFIGURATION", paste(
      "Project root:       ", root,
      "\nModel:              ", model,
      "\nSpecification:      ", spec_path,
      "\nIndependent ADSL:    ", registered_adsl_path,
      "\nUpstream QC report:  ", adsl_qc_report_path,
      "\nProduction table:   ", production_path,
      "\nGenerated code:     ", generated_code_path,
      "\nIndependent table:  ", independent_path,
      "\nQC report:          ", report_path,
      sep = ""
    ))
    t14_qc_log("SYSTEM REQUEST SENT TO LLM", system_prompt)
    t14_qc_log("USER REQUEST SENT TO LLM", user_prompt)
  }

  # STEP 4 — Send the prompts through the configured agent and record the full
  # raw provider response.
  cat("\nRequesting T14.2.01 R program from ", model, "...\n", sep = "")
  request_t14_program <- integrity_compute(
    context = sdk$ctx,
    metadata = list(
      "name" = "Request Independent T14.2.01 R Program",
      "description" = "Sends the system and user prompts through the configured code-generation agent",
      "author" = "Eqty Lab"
    ),
    `_store` = TRUE,
    func = t14_qc_request_model
  )
  d_raw_response <- request_t14_program(
    d_agent,
    d_system_prompt,
    d_user_prompt
  )

  # STEP 5 — Extract R source and token usage from the raw response, validate
  # the source, and register both outputs of response processing.
  process_t14_response <- integrity_compute(
    context = sdk$ctx,
    metadata = list(
      "name" = "Process and Validate T14.2.01 Provider Response",
      "description" = "Extracts R source and token usage from the raw provider response and validates the source before local execution",
      "author" = "Eqty Lab"
    ),
    `_store` = TRUE,
    func = function(raw_response_document) {
      response_record <- t14_qc_asset_value(raw_response_document)
      code <- t14_qc_extract_r_code(as.character(response_record$response_text))
      t14_qc_validate_generated_code(
        code,
        required_paths = c(registered_adsl_path, independent_path),
        forbidden_paths = c(
          production_path,
          normalize(file.path("data", "production", "adsl.csv")),
          normalize(file.path("data", "spec", "t14_2_01.R")),
          file.path("data", "production", "T14_2_01.csv"),
          file.path("data", "production", "adsl.csv"),
          file.path("data", "spec", "t14_2_01.R")
        )
      )
      writeLines(code, generated_code_path, useBytes = TRUE)

      if (isTRUE(verbose)) {
        t14_qc_log(paste0("GENERATED R CODE (", generated_code_path, ")"), code)
      }

      generated_code <- Code$with_context(sdk$ctx)$from_path(
        generated_code_path,
        name = basename(generated_code_path),
        description = paste0("Validated R source generated by ", model, " from the T14.2.01 specification"),
        `_store` = TRUE
      )
      token_usage <- Token$with_context(sdk$ctx)$from_object(
        do.call(integrity_dict, response_record$token_usage),
        name = "T14.2.01 agent token usage",
        description = "Input, output, and cached input token counts reported by ellmer",
        model = model,
        `_store` = TRUE
      )

      list(generated_code, token_usage)
    }
  )
  processed_response <- process_t14_response(d_raw_response)
  d_generated_code <- processed_response[[1L]]
  d_token_usage <- processed_response[[2L]]

  # STEP 6 — Run locally after checking the registered upstream QC evidence.
  execute_t14_program <- integrity_compute(
    context = sdk$ctx,
    metadata = list(
      "name" = "Execute Independent T14.2.01 Derivation",
      "description" = "Executes the validated generated R program locally against the approved upstream independent ADSL",
      "author" = "Eqty Lab"
    ),
    `_store` = TRUE,
    func = function(generated_code, adsl_dataset, upstream_qc_report) {
      resolved_code_path <- as.character(integrity_resolve_path(generated_code))
      resolved_adsl_path <- as.character(integrity_resolve_path(adsl_dataset))
      resolved_qc_report_path <- as.character(integrity_resolve_path(upstream_qc_report))
      invisible(t14_qc_read_adsl(resolved_adsl_path))
      invisible(t14_qc_validate_upstream_adsl(resolved_qc_report_path))

      if (file.exists(independent_path)) {
        unlink(independent_path, force = TRUE)
      }

      cat("Executing generated T14.2.01 R program locally...\n")
      original_working_directory <- getwd()
      on.exit(setwd(original_working_directory), add = TRUE)
      setwd(root)
      sys.source(resolved_code_path, envir = new.env(parent = globalenv()))
      if (!file.exists(independent_path)) {
        stop("Generated R code finished without writing: ", independent_path, call. = FALSE)
      }
      independent <- t14_qc_read(independent_path, "Independent T14.2.01")
      cat("Generated T14.2.01 written: ", independent_path, " (", nrow(independent), " rows)\n", sep = "")

      Dataset$with_context(sdk$ctx)$from_path(
        independent_path,
        name = basename(independent_path),
        description = "Independent T14.2.01 generated locally from the approved upstream independent ADSL",
        `_store` = TRUE
      )
    }
  )
  d_independent <- execute_t14_program(d_generated_code, d_adsl, d_adsl_qc_report)

  # STEP 7 — Compare the independent table with the production table.
  compare_t14_outputs <- integrity_compute(
    context = sdk$ctx,
    metadata = list(
      "name" = "Compare Independent and Production T14.2.01",
      "description" = "Performs deterministic row- and column-level comparison and writes the T14.2.01 QC discrepancy report",
      "author" = "Eqty Lab"
    ),
    `_store` = TRUE,
    func = function(production_dataset, independent_dataset) {
      resolved_production_path <- as.character(integrity_resolve_path(production_dataset))
      resolved_independent_path <- as.character(integrity_resolve_path(independent_dataset))

      cat("Comparing generated T14.2.01 with production T14.2.01...\n")
      report <- t14_qc_compare(
        resolved_production_path,
        resolved_independent_path,
        report_path
      )
      failed <- report$is_critical & report$n_mismatch > 0L
      qc_status <- if (any(failed)) "FAILED" else "PASSED"

      Dataset$with_context(sdk$ctx)$from_path(
        report_path,
        name = basename(report_path),
        description = paste0(
          "Deterministic production-versus-independent T14.2.01 discrepancy report; QC status: ",
          qc_status
        ),
        `_store` = TRUE
      )
    }
  )
  d_report <- compare_t14_outputs(d_production, d_independent)

  registered_report_path <- as.character(integrity_resolve_path(d_report))
  report <- utils::read.csv(registered_report_path, stringsAsFactors = FALSE)
  failed <- report$is_critical & report$n_mismatch > 0L

  # STEP 8 — Add an explicit validation result at the end of the lineage graph.
  validate_t14_qc_result <- integrity_compute(
    context = sdk$ctx,
    metadata = list(
      "name" = "Validate T14.2.01 QC Result",
      "description" = "Evaluates the T14.2.01 discrepancy report and produces the final validation decision",
      "author" = "Eqty Lab"
    ),
    `_store` = TRUE,
    func = function(report_dataset) {
      resolved_report_path <- as.character(integrity_resolve_path(report_dataset))
      validation_report <- utils::read.csv(resolved_report_path, stringsAsFactors = FALSE)
      validation_failed <- validation_report$is_critical & validation_report$n_mismatch > 0L

      result <- integrity_dict(
        valid = !any(validation_failed),
        status = if (any(validation_failed)) "FAILED" else "PASSED",
        critical_failures = paste(
          validation_report$item[validation_failed],
          collapse = ", "
        )
      )

      Document$with_context(sdk$ctx)$from_object(
        result,
        name = "T14.2.01 QC Validation Result",
        description = "Final valid or invalid decision produced from the T14.2.01 QC discrepancy report",
        `_store` = TRUE
      )
    }
  )
  d_validation <- validate_t14_qc_result(d_report)

  # Export this execution separately. sample_03_merge.R combines it with the ADSL graph.
  invisible(sdk$ctx$export(integrity_path(manifest_path)))

  if (any(failed)) {
    stop(
      "T14.2.01 QC failed for critical item(s): ",
      paste(report$item[failed], collapse = ", "),
      ". See ", report_path, ".",
      call. = FALSE
    )
  }

  result <- list(
    status = "PASSED",
    report = report,
    independent_adsl_path = independent_adsl_path,
    adsl_qc_report_path = adsl_qc_report_path,
    production_path = production_path,
    output_path = independent_path,
    report_path = report_path,
    generated_code_path = generated_code_path,
    manifest_path = manifest_path
  )
  if (isTRUE(verbose)) {
    t14_qc_log("QC RESULT", paste(
      "Status: ", result$status,
      "\nReport: ", result$report_path,
      "\nManifest: ", result$manifest_path,
      "\n\nReport contents:\n",
      paste(capture.output(print(result$report, row.names = FALSE)), collapse = "\n"),
      sep = ""
    ))
  }

  cat("\nT14.2.01 QC PASSED\n")
  cat("Manifest successfully generated and exported to output/manifest-t14-2-01.json.\n")
  invisible(result)
}

# Running this file starts the live workflow; sourcing it loads only helpers.
if (sys.nframe() == 0L) {
  run_live_t14_2_01_qc_demo()
}
