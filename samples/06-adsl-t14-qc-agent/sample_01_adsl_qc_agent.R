#!/usr/bin/env Rscript

# Live ADSL QC demonstration
#
# Workflow: specification + file names -> LLM generates R -> local R runs it
# -> independent ADSL -> comparison with production ADSL -> pass/fail report.
# No subject-level data or production ADSL is sent to LLM.

library(eqty.sdk.r)

# ---- EQTY SDK configuration -------------------------------------------------
# The SDK is initialized only when the live workflow runs. Keeping setup out of
# package/source time lets the deterministic comparison helpers remain usable.

# ---- EQTY SDK helpers -------------------------------------------------------

adsl_qc_integrity_init <- function() {
  ctx <- Context$new(
    "LZZT_001 — Live ADSL Independent LLM QC"
  )
  invisible(integrity_init(default_context = ctx))

  signer <- Signer$load_or_create(name = "eqty-r-adsl-qc")
  invisible(integrity_set_active_signer(signer))
  signer_did <- DID$from_signer(
    signer,
    name = "Alice",
    description = "Local signer"
  )

  list(ctx = ctx, signer_did = signer_did)
}

# ---- General helpers --------------------------------------------------------
# These small functions deal only with paths and console output. They do not
# read study data, call LLM, or make QC decisions.

adsl_qc_root <- function() {
  # Prefer an explicitly configured project folder. Otherwise, treat the
  # current R working directory as the project folder.
  configured <- Sys.getenv("RWE_PROJECT_ROOT", unset = "")
  if (nzchar(configured)) {
    return(normalizePath(configured, mustWork = FALSE))
  }

  normalizePath(getwd(), mustWork = FALSE)
}

adsl_qc_resolve <- function(path, root) {
  # A path beginning with / is already absolute. All other paths are relative
  # to the example root, for example data/production/adsl.csv.
  if (grepl("^(/|[A-Za-z]:[/\\\\])", path)) {
    return(path)
  }

  file.path(root, path)
}

adsl_qc_log <- function(title, text) {
  # Use a consistent console format so live-run output is easy to scan.
  cat("\n", strrep("=", 78), "\n", title, "\n", strrep("-", 78), "\n", text, "\n", sep = "")
}

# ---- Deterministic QC comparison -------------------------------------------
# These functions compare two already-created ADSL CSV files. They have no LLM
# dependency, so they can also be used for ordinary non-LLM double programming.

adsl_qc_read <- function(path, label) {
  # Check that the input looks like a subject-level ADSL dataset before trying
  # to compare it: the file must exist, include USUBJID, and have one row per ID.
  if (!file.exists(path)) {
    stop(label, " not found: ", path, call. = FALSE)
  }

  data <- utils::read.csv(
    path,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  if (!"USUBJID" %in% names(data)) {
    stop(label, " must contain USUBJID.", call. = FALSE)
  }

  duplicate_ids <- unique(data$USUBJID[duplicated(data$USUBJID)])
  if (length(duplicate_ids)) {
    stop(label, " has duplicate USUBJID values: ", paste(duplicate_ids, collapse = ", "), call. = FALSE)
  }

  data
}

adsl_qc_mismatch <- function(left, right) {
  left <- as.character(left)
  right <- as.character(right)

  # Two missing values match. TRUE means a mismatch for that subject.
  !(is.na(left) & is.na(right)) & (is.na(left) | is.na(right) | left != right)
}

adsl_qc_compare <- function(production_adsl_data_path, independent_path, critical_vars, report_path) {
  production <- adsl_qc_read(production_adsl_data_path, "Production ADSL")
  independent <- adsl_qc_read(independent_path, "Independent ADSL")

  production_ids <- as.character(production$USUBJID)
  independent_ids <- as.character(independent$USUBJID)
  missing_ids <- setdiff(production_ids, independent_ids)
  unexpected_ids <- setdiff(independent_ids, production_ids)
  common_columns <- setdiff(intersect(names(production), names(independent)), "USUBJID")
  missing_critical <- setdiff(critical_vars, names(independent))

  # Align the two tables to the same subject order before comparing columns.
  common_ids <- intersect(production_ids, independent_ids)
  production <- production[match(common_ids, production_ids), , drop = FALSE]
  independent <- independent[match(common_ids, independent_ids), , drop = FALSE]
  n_compared <- nrow(production)

  # Make one report row for every variable that both datasets contain. `lapply`
  # repeats the same comparison for each variable and returns a list of rows.
  variable_rows <- lapply(common_columns, function(variable) {
    mismatches <- adsl_qc_mismatch(production[[variable]], independent[[variable]])
    data.frame(
      variable = variable, is_critical = variable %in% critical_vars,
      n_compared = n_compared, n_mismatch = sum(mismatches),
      match_rate = 1 - sum(mismatches) / max(n_compared, 1L), stringsAsFactors = FALSE
    )
  })

  # If an expected critical variable is absent from the independent ADSL, add a
  # failure row to the report rather than silently skipping that variable.
  missing_rows <- lapply(missing_critical, function(variable) {
    data.frame(variable = variable, is_critical = TRUE, n_compared = n_compared,
               n_mismatch = n_compared, match_rate = 0, stringsAsFactors = FALSE)
  })

  # Subject IDs are treated as a critical item. Any missing or unexpected
  # subject is therefore a QC failure even if all common subjects match.
  subject_row <- data.frame(
    variable = "USUBJID", is_critical = TRUE, n_compared = n_compared,
    n_mismatch = length(missing_ids) + length(unexpected_ids),
    match_rate = as.numeric(!length(missing_ids) && !length(unexpected_ids)), stringsAsFactors = FALSE
  )

  # Combine the subject row and all variable rows into one data frame. `rbind`
  # means "bind rows together".
  report <- do.call(rbind, c(list(subject_row), variable_rows, missing_rows))

  utils::write.csv(report, report_path, row.names = FALSE, na = "")

  report
}

run_adsl_qc <- function(
  production_adsl_data_path = file.path("data", "production", "adsl.csv"),
  llm_generated__adsl_data_path = file.path("data", "independent", "adsl_llm.csv"),
  report_path = file.path("output", "adsl_qc_discrepancy_report.csv"),
  critical_vars = c("SAFFL", "ITTFL", "EFFFL", "AGEGR1", "AGEGR1N", "EOSSTT", "DCDECOD", "COMP8FL", "COMP16FL", "COMP24FL"),
  root = adsl_qc_root()
) {
  # Convert the default relative paths to concrete paths before reading files.
  production_adsl_data_path <- adsl_qc_resolve(production_adsl_data_path, root)
  llm_generated__adsl_data_path <- adsl_qc_resolve(llm_generated__adsl_data_path, root)
  report_path <- adsl_qc_resolve(report_path, root)
  report <- adsl_qc_compare(
    production_adsl_data_path,
    llm_generated__adsl_data_path,
    critical_vars,
    report_path
  )

  # Critical mismatches stop the workflow. Non-critical mismatches stay in the
  # CSV report but do not prevent a PASS result.
  failed <- report$is_critical & report$n_mismatch > 0L
  if (any(failed)) {
    stop("ADSL QC failed for critical item(s): ", paste(report$variable[failed], collapse = ", "),
         ". See ", report_path, ".", call. = FALSE)
  }

  invisible(list(
    status = "PASSED", report = report,
    production_adsl_data_path = production_adsl_data_path,
    output_path = llm_generated__adsl_data_path,
    report_path = report_path,
    noncritical_differences = sum(!report$is_critical & report$n_mismatch > 0L)
  ))
}

# ---- LLM code generation and local execution -------------------------------
# LLM receives the derivation instructions and returns R source code. The
# source code is saved and run locally; LLM never receives the CSV contents.

adsl_qc_extract_r_code <- function(response) {
  # Models may return either plain R code or a Markdown ```r code block. Accept
  # both formats, but reject an empty answer before attempting execution.
  response <- trimws(as.character(response))

  match <- regexec("```[rR]?[[:space:]]*([\\s\\S]*?)```", response, perl = TRUE)

  parts <- regmatches(response, match)[[1L]]
  if (length(parts) >= 2L) {
    code <- trimws(parts[[2L]])
  } else {
    code <- response
  }

  if (!nzchar(code)) {
    stop("LLM returned no R code.", call. = FALSE)
  }

  code
}

adsl_qc_validate_generated_code <- function(code) {
  # `parse()` checks R syntax without running the code.
  parsed <- tryCatch(parse(text = code), error = function(error) {
    stop("Generated R code does not parse: ", conditionMessage(error), call. = FALSE)
  })

  # This deny-list catches common operations that should never be present in a
  # generated derivation program. It is a basic guardrail, not a true sandbox.
  blocked_calls <- c("system", "system2", "shell", "pipe", "download.file", "url", "socketConnection",
                     "unlink", "file.remove", "file.rename", "setwd", "Sys.setenv", "source", "dyn.load", "install.packages")
  text <- paste(deparse(parsed), collapse = "\n")

  # Look through the parsed source for a call to any blocked function.
  used <- blocked_calls[vapply(blocked_calls, function(name) {
    grepl(paste0("(^|[^[:alnum:]_.])", name, "[[:space:]]*\\("), text, perl = TRUE)
  }, logical(1L))]

  if (length(used)) {
    stop("Generated R code uses blocked call(s): ", paste(used, collapse = ", "), call. = FALSE)
  }

  invisible(parsed)
}

adsl_qc_asset_value <- function(asset) {
  value <- asset$value
  if (reticulate::is_py_object(value)) {
    return(reticulate::py_to_r(value))
  }
  value
}

adsl_qc_request_model <- function(agent_asset, system_prompt_asset, user_prompt_asset) {
  # ellmer is the R package that sends the prompts to LLM API.
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("Package 'ellmer' is required. Install it with install.packages('ellmer').", call. = FALSE)
  }

  agent_config <- adsl_qc_asset_value(agent_asset)
  system_prompt <- as.character(adsl_qc_asset_value(system_prompt_asset))
  user_prompt <- as.character(adsl_qc_asset_value(user_prompt_asset))
  model <- agent_config$model
  if (is.null(model) || !nzchar(as.character(model))) {
    stop("The ADSL code-generation Agent does not define a model.", call. = FALSE)
  }
  model <- as.character(model)

  # `echo = "none"` returns the answer to this script instead of streaming it
  # directly to the console. The script prints it later in a labelled section.
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
    name = "Raw ADSL provider response",
    description = "Complete unprocessed provider response and response metadata retained by ellmer",
    `_store` = TRUE
  )
}

adsl_qc_project_root <- function() {
  # Find this self-contained example when started from its folder or an IDE.
  args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  candidates <- c(getwd(), file.path(getwd(), ".."))
  if (length(args)) {
    script_path <- sub("^--file=", "", args[[1L]])
    candidates <- c(candidates, file.path(dirname(script_path), ".."))
  }
  candidates <- unique(candidates)

  found <- vapply(
    candidates,
    function(path) file.exists(file.path(path, "data", "spec", "adsl_spec.txt")),
    logical(1L)
  )

  if (!any(found)) {
    stop("Run from the 06-adsl-t14-qc-agent example directory.", call. = FALSE)
  }

  normalizePath(candidates[[which(found)[[1L]]]], mustWork = TRUE)
}

run_live_adsl_qc_demo <- function(
  spec_path = file.path("data", "spec", "adsl_spec.txt"),
  sdtm_paths = file.path("data", "sdtm", c("RWD_DM.csv", "RWD_VS.csv", "RWD_QS.csv", "RWD_MH.csv", "RWD_SC.csv", "RWD_LB.csv")),
  production_adsl_data_path = file.path("data", "production", "adsl.csv"),
  llm_generated__adsl_data_path = file.path("output", "adsl_llm.csv"),
  generated_code_path = file.path("output", "adsl_generated.R"),
  model = Sys.getenv("GEMINI_MODEL", unset = "gemini-3.8-flash"),
  critical_vars = c("SAFFL", "ITTFL", "EFFFL", "AGEGR1", "AGEGR1N", "EOSSTT", "DCDECOD", "COMP8FL", "COMP16FL", "COMP24FL"),
  root = adsl_qc_project_root(), verbose = TRUE
) {
  # STEP 1 — Resolve all paths and check that the specification and each SDTM
  # input file exist. No files are sent to the LLM at this point.

  root <- normalizePath(root, mustWork = TRUE)
  normalize <- function(path) normalizePath(adsl_qc_resolve(path, root), mustWork = FALSE)

  # Text file containing the ADSL derivation rules sent to the LLM.
  spec_path <- normalize(spec_path)

  # SDTM CSV files that the generated R program will read at runtime.
  sdtm_paths <- vapply(sdtm_paths, normalize, character(1L))

  # Validated ADSL CSV used only as the comparison reference after derivation.
  production_adsl_data_path <- normalize(production_adsl_data_path)

  # Independent ADSL CSV that the generated R program is required to create.
  llm_generated__adsl_data_path <- normalize(llm_generated__adsl_data_path)

  # Saved copy of the R source code returned by the LLM, before it is executed.
  generated_code_path <- normalize(generated_code_path)
  if (!file.exists(spec_path)) {
    stop("ADSL specification not found: ", spec_path, call. = FALSE)
  }
  missing_inputs <- sdtm_paths[!file.exists(sdtm_paths)]
  if (length(missing_inputs)) {
    stop("Required SDTM input(s) not found: ", paste(missing_inputs, collapse = ", "), call. = FALSE)
  }
  if (!file.exists(production_adsl_data_path)) {
    stop("Production ADSL not found: ", production_adsl_data_path, call. = FALSE)
  }

  if (length(sdtm_paths) != 6L) {
    stop("The live ADSL derivation requires exactly six SDTM inputs.", call. = FALSE)
  }

  report_path <- file.path(root, "output", "adsl_qc_discrepancy_report.csv")
  manifest_path <- "output/manifest-adsl.json"

  # STEP 2 — Initialize the SDK with a default context and create the
  # path-backed input assets. integrity_compute records the executable stages.
  sdk <- adsl_qc_integrity_init()

  d_spec <- Document$with_context(sdk$ctx)$from_path(
    spec_path,
    name = basename(spec_path),
    description = "Independent ADSL derivation specification supplied to the LLM",
   `_store`=TRUE
  )
  d_sdtm_inputs <- lapply(sdtm_paths, function(path) {
    Dataset$with_context(sdk$ctx)$from_path(
      path,
      name = basename(path),
      description = "SDTM input read locally by the generated independent ADSL program",
     `_store`=TRUE
    )
  })
  d_production <- Dataset$with_context(sdk$ctx)$from_path(
    production_adsl_data_path,
    name = basename(production_adsl_data_path),
    description = "Validated production ADSL used only as the deterministic QC reference",
   `_store`=TRUE
  )
  # Resolve the registered SDTM assets now so the generated program reads the
  # same files that are passed to the execution computation.
  registered_input_files <- vapply(
    d_sdtm_inputs,
    function(asset) as.character(integrity_resolve_path(asset)),
    character(1L)
  )

  # STEP 3 — Create the user prompt from the registered ADSL specification and
  # record that transformation before contacting the agent. The system prompt
  # is configured independently and is not an output of this computation.
  system_prompt <- paste(
    "You are an independent clinical programmer.",
    "Return only one complete executable R program; no explanation, Markdown, CSV, or data values.",
    "Use only base R and utils::read.csv / utils::write.csv.",
    "Your program must read supplied CSV files at runtime; never embed or invent input rows.",
    "Handle empty filtered data and all-missing source values without error; check again after removing missing values before calling aggregate().",
    "When no qualifying non-missing source value exists, assign the corresponding derived value as missing.",
    "The output directory already exists; write the requested CSV directly without checking or creating directories.",
    "Do not call the operating system, network, package installation, or production ADSL."
  )
  d_agent <- Agent$with_context(sdk$ctx)$from_object(
    integrity_dict(
      package = "ellmer",
      provider = "Google Gemini",
      model = model
    ),
    name = "ADSL code-generation agent",
    description = "Ellmer Gemini agent configured to generate the independent ADSL R program"
  )
  d_system_prompt <- SystemPrompt$with_context(sdk$ctx)$from_object(
    system_prompt,
    name = "ADSL code-generation system prompt",
    description = "System instructions supplied to the model",
    `_store` = TRUE
  )
  create_adsl_user_prompt <- integrity_compute(
    context = sdk$ctx,
    metadata = list(
      "name" = "Create ADSL Code-generation User Prompt",
      "description" = "Creates the user prompt from the ADSL specification",
      "author" = "Eqty Lab"
    ),
    `_store` = TRUE,
    func = function(spec_document) {
      resolved_spec_path <- as.character(integrity_resolve_path(spec_document))
      prompt_text <- paste(
        "Derive one ADSL row per USUBJID exactly from this specification:",
        paste(readLines(resolved_spec_path, warn = FALSE), collapse = "\n"),
        "", "Study-specific derivation clarification (mandatory):",
        "- For RWD_QS, the baseline MMSE record is QSTESTCD == 'MMS112' and VISITNUM == 3.",
        "- Do not use VISITNUM == 1 as a substitute for baseline MMSE.",
        "", "Read only these registered SDTM CSV files:",
        paste(registered_input_files, collapse = "\n"),
        "", "Write the derived CSV to:", llm_generated__adsl_data_path,
        sep = "\n"
      )

      Prompt$with_context(sdk$ctx)$from_object(
        prompt_text,
        name = "ADSL code-generation user prompt",
        description = "User request supplied to the model",
        `_store` = TRUE
      )
    }
  )
  d_user_prompt <- create_adsl_user_prompt(d_spec)
  user_prompt <- as.character(adsl_qc_asset_value(d_user_prompt))

  if (isTRUE(verbose)) {
    adsl_qc_log("LIVE ADSL QC — CONFIGURATION", paste(
      "Project root:       ", root,
      "\nModel:              ", model,
      "\nSpecification:      ", spec_path,
      "\nSDTM input files:\n  ", paste(registered_input_files, collapse = "\n  "),
      "\nProduction ADSL:    ", production_adsl_data_path,
      "\nGenerated code:     ", generated_code_path,
      "\nIndependent ADSL:   ", llm_generated__adsl_data_path,
      "\nQC report:          ", report_path,
      sep = ""
    ))
    adsl_qc_log("SYSTEM REQUEST SENT TO LLM", system_prompt)
    adsl_qc_log("USER REQUEST SENT TO LLM", user_prompt)
  }

  # STEP 4 — Send the prompts through the configured agent and record the full
  # raw provider response.
  cat("\nRequesting ADSL R program from ", model, "...\n", sep = "")
  request_adsl_program <- integrity_compute(
    context = sdk$ctx,
    metadata = list(
      "name" = "Request Independent ADSL R Program",
      "description" = "Sends the system and user prompts through the configured code-generation agent",
      "author" = "Eqty Lab"
    ),
    `_store` = TRUE,
    func = adsl_qc_request_model
  )
  d_raw_response <- request_adsl_program(
    d_agent,
    d_system_prompt,
    d_user_prompt
  )

  # STEP 5 — Extract R source from the raw response, validate it, and register
  # the saved program and token usage as outputs of response processing.
  process_adsl_response <- integrity_compute(
    context = sdk$ctx,
    metadata = list(
      "name" = "Process and Validate ADSL Provider Response",
      "description" = "Extracts R source and token usage from the raw provider response and validates the source before local execution",
      "author" = "Eqty Lab"
    ),
    `_store` = TRUE,
    func = function(raw_response_document) {
      response_record <- adsl_qc_asset_value(raw_response_document)
      code <- adsl_qc_extract_r_code(as.character(response_record$response_text))
      adsl_qc_validate_generated_code(code)
      writeLines(code, generated_code_path, useBytes = TRUE)

      if (isTRUE(verbose)) {
        adsl_qc_log(paste0("GENERATED R CODE (", generated_code_path, ")"), code)
      }

      generated_code <- Code$with_context(sdk$ctx)$from_path(
        generated_code_path,
        name = basename(generated_code_path),
        description = paste0("Validated R source generated by ", model, " from the independent ADSL specification"),
        `_store` = TRUE
      )
      token_usage <- Token$with_context(sdk$ctx)$from_object(
        do.call(integrity_dict, response_record$token_usage),
        name = "ADSL agent token usage",
        description = "Input, output, and cached input token counts reported by ellmer",
        model = model,
        `_store` = TRUE
      )

      list(generated_code, token_usage)
    }
  )
  processed_response <- process_adsl_response(d_raw_response)
  d_generated_code <- processed_response[[1L]]
  d_token_usage <- processed_response[[2L]]

  # STEP 6 — Execute the generated program locally. Every SDTM Dataset is an
  # explicit integrity_compute input, and the independent ADSL is its Dataset output.
  execute_adsl_program <- integrity_compute(
    context = sdk$ctx,
    metadata = list(
      "name" = "Execute Independent ADSL Derivation",
      "description" = "Executes the validated generated R program locally against the six registered SDTM inputs",
      "author" = "Eqty Lab"
    ),
    `_store` = TRUE,
    func = function(generated_code, dm, vs, qs, mh, sc, lb) {
      resolved_code_path <- as.character(integrity_resolve_path(generated_code))
      resolved_inputs <- vapply(
        list(dm, vs, qs, mh, sc, lb),
        function(asset) as.character(integrity_resolve_path(asset)),
        character(1L)
      )
      missing_registered_inputs <- resolved_inputs[!file.exists(resolved_inputs)]
      if (length(missing_registered_inputs)) {
        stop("Registered SDTM input(s) not found: ", paste(missing_registered_inputs, collapse = ", "), call. = FALSE)
      }

      if (file.exists(llm_generated__adsl_data_path)) {
        unlink(llm_generated__adsl_data_path, force = TRUE)
      }

      cat("Executing generated R program locally...\n")
      original_working_directory <- getwd()
      on.exit(setwd(original_working_directory), add = TRUE)
      setwd(root)
      tryCatch(
        sys.source(resolved_code_path, envir = new.env(parent = globalenv())),
        error = function(error) {
          stop(
            "Generated R program failed during local execution: ",
            conditionMessage(error),
            call. = FALSE
          )
        }
      )
      if (!file.exists(llm_generated__adsl_data_path)) {
        stop("Generated R code finished without writing: ", llm_generated__adsl_data_path, call. = FALSE)
      }
      cat(
        "Generated ADSL written: ", llm_generated__adsl_data_path, " (",
        nrow(utils::read.csv(llm_generated__adsl_data_path)), " rows)\n",
        sep = ""
      )

      Dataset$with_context(sdk$ctx)$from_path(
        llm_generated__adsl_data_path,
        name = basename(llm_generated__adsl_data_path),
        description = "Independent ADSL generated locally from the registered SDTM inputs",
       `_store`=TRUE
      )
    }
  )
  d_independent <- execute_adsl_program(
    d_generated_code,
    d_sdtm_inputs[[1L]],
    d_sdtm_inputs[[2L]],
    d_sdtm_inputs[[3L]],
    d_sdtm_inputs[[4L]],
    d_sdtm_inputs[[5L]],
    d_sdtm_inputs[[6L]]
  )

  # STEP 7 — Compare the independent and production ADSL datasets. The wrapper
  # always returns the report asset; the critical gate is applied afterwards so
  # failed QC evidence remains part of the verifiable computation.
  compare_adsl_outputs <- integrity_compute(
    context = sdk$ctx,
    metadata = list(
      "name" = "Compare Independent and Production ADSL",
      "description" = "Performs deterministic subject- and variable-level ADSL comparison and writes the QC discrepancy report",
      "author" = "Eqty Lab"
    ),
    `_store` = TRUE,
    func = function(production_dataset, independent_dataset) {
      resolved_production_path <- as.character(integrity_resolve_path(production_dataset))
      resolved_independent_path <- as.character(integrity_resolve_path(independent_dataset))

      cat("Comparing generated ADSL with production ADSL...\n")
      report <- adsl_qc_compare(
        resolved_production_path,
        resolved_independent_path,
        critical_vars,
        report_path
      )
      failed <- report$is_critical & report$n_mismatch > 0L
      qc_status <- if (any(failed)) "FAILED" else "PASSED"

      Dataset$with_context(sdk$ctx)$from_path(
        report_path,
        name = basename(report_path),
        description = paste0(
          "Deterministic production-versus-independent ADSL discrepancy report; QC status: ",
          qc_status
        ),
       `_store`=TRUE
      )
    }
  )

  d_report <- compare_adsl_outputs(d_production, d_independent)

  # The report is an output of integrity_compute. Read it before creating the
  # final validation result and exporting the context.
  registered_report_path <- as.character(integrity_resolve_path(d_report))
  report <- utils::read.csv(registered_report_path, stringsAsFactors = FALSE)
  failed <- report$is_critical & report$n_mismatch > 0L

  # STEP 8 — Produce a final validation node from the discrepancy report. The
  # output is an in-memory object so the lineage ends with an explicit valid or
  # invalid result rather than only the report file.
  validate_adsl_qc_result <- integrity_compute(
    context = sdk$ctx,
    metadata = list(
      "name" = "Validate ADSL QC Result",
      "description" = "Evaluates the ADSL discrepancy report and produces the final validation decision",
      "author" = "Eqty Lab"
    ),
    `_store` = TRUE,
    func = function(report_dataset) {
      resolved_report_path <- as.character(integrity_resolve_path(report_dataset))
      validation_report <- utils::read.csv(
        resolved_report_path,
        stringsAsFactors = FALSE
      )
      validation_failed <- validation_report$is_critical &
        validation_report$n_mismatch > 0L

      result <- integrity_dict(
        valid = !any(validation_failed),
        status = if (any(validation_failed)) "FAILED" else "PASSED",
        critical_failures = paste(
          validation_report$variable[validation_failed],
          collapse = ", "
        ),
        noncritical_differences = sum(
          !validation_report$is_critical &
            validation_report$n_mismatch > 0L
        )
      )

      Document$with_context(sdk$ctx)$from_object(
        result,
        name = "ADSL QC Validation Result",
        description = "Final valid or invalid decision produced from the ADSL QC discrepancy report",
        `_store` = TRUE
      )
    }
  )
  d_validation <- validate_adsl_qc_result(d_report)

  invisible(sdk$ctx$export(integrity_path(manifest_path)))

  if (any(failed)) {
    stop(
      "ADSL QC failed for critical item(s): ",
      paste(report$variable[failed], collapse = ", "),
      ". See ", report_path, ".",
      call. = FALSE
    )
  }

  result <- list(
    status = "PASSED",
    report = report,
    production_adsl_data_path = production_adsl_data_path,
    output_path = llm_generated__adsl_data_path,
    report_path = report_path,
    generated_code_path = generated_code_path,
    manifest_path = manifest_path,
    noncritical_differences = sum(!report$is_critical & report$n_mismatch > 0L)
  )
  if (isTRUE(verbose)) {
    adsl_qc_log("QC RESULT", paste(
      "Status: ", result$status,
      "\nNon-critical differences: ", result$noncritical_differences,
      "\nReport: ", result$report_path,
      "\n\nReport contents:\n",
      paste(capture.output(print(result$report, row.names = FALSE)), collapse = "\n"),
      sep = ""
    ))
  }

  cat("\nADSL QC PASSED\n")
  cat("Manifest successfully generated and exported to output/manifest-adsl.json.\n")
  invisible(result)
}

# `Rscript sample_01_adsl_qc_agent.R` starts the live workflow. When this file
# is sourced by test_adsl_qc_demo_agent.R, only its functions are loaded.
if (sys.nframe() == 0L) {
  run_live_adsl_qc_demo()
}
