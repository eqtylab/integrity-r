# NAME
#     generate-verifiable-plot-gitcommit.R - Verify a GitHub commit's GPG
#     signature, fetch the referenced CSV, and record the full chain
#
# SYNOPSIS
#     Rscript generate-verifiable-plot-gitcommit.R [GH_USER] [GH_REPO] [GH_COMMIT] [GH_FILE]
#
# DESCRIPTION
#     Fetches data and extracts the CRYPTOGRAPHICALLY TRUSTED identity from the
#     GPG payload of a GitHub commit (ignoring the untrusted Git author field),
#     then chains three verifiable computation steps:
#       1. Fetch a GitHub commit and verify its GPG signature status.
#       2. Download the CSV referenced by that (verified) commit.
#       3. Plot the data, annotating it with the verified signer identity.
#     Each step is a Computation with input and output CIDs. The context groups
#     the related assets and computations for export in one manifest.
#
#     The example uses explicit Context and Computation wiring so that every
#     stage of the verification and plotting workflow is part of the lineage.
#
# ARGUMENTS
#     [GH_USER]     Optional. Defaults to 'ahiatsevich'.
#     [GH_REPO]     Optional. Defaults to 'test-gpg'.
#     [GH_COMMIT]   Optional. Defaults to a known-signed sample commit.
#     [GH_FILE]     Optional. Defaults to 'population.csv'.
#
# DEPENDENCIES
#     R packages: eqty.sdk.r, ggplot2, scales, httr, jsonlite
#     Env:        GITHUB_PAT (optional, raises GitHub API rate limits)
library(eqty.sdk.r)
library(ggplot2)
library(scales)
library(httr)
library(jsonlite)

ctx <- Context$new("[Sample] GitHub GPG Chain: Data Processing Run V1")
invisible(integrity_init(default_context = ctx))
signer <- Signer$load_or_create(name = "eqty-r-github-plot")
invisible(integrity_set_active_signer(signer))
signer_did <- DID$from_signer(
  signer,
  name = "Alice and Bob",
  description = "Local signer"
)

args <- commandArgs(trailingOnly = TRUE)

output_folder <- "./output"
gh_user       <- "ahiatsevich"
gh_repo       <- "test-gpg"
gh_commit     <- "1779d227f3a8b114bf5e04694f1d0ed7902959c9" # The commit from your log
gh_file       <- "population.csv"

if (length(args) >= 1) gh_user   <- args[1]
if (length(args) >= 2) gh_repo   <- args[2]
if (length(args) >= 3) gh_commit <- args[3]
if (length(args) >= 4) gh_file   <- args[4]

input_params <- list(
  gh_user = gh_user,
  gh_repo = gh_repo,
  gh_commit = gh_commit,
  gh_file = gh_file,
  output_folder = output_folder
)
input_json_path <- file.path(output_folder, "input_params.json")
write_json(input_params, input_json_path, auto_unbox = TRUE)

d_params <- Dataset$with_context(ctx)$from_path(input_json_path,
  name = "Parameters to download data from GitHub",
  description = "Parameters for fetching data from GitHub"
)

gh_token <- Sys.getenv("GITHUB_PAT")
req_headers <- list()
if (gh_token != "") {
  req_headers <- add_headers(Authorization = paste("token", gh_token))
}

api_url <- paste0("https://api.github.com/repos/", gh_user, "/", gh_repo, "/commits/", gh_commit)
cat("Fetching commit info from: ", api_url, "\n", sep = "")

resp <- GET(api_url, req_headers)
if (status_code(resp) != 200) stop(paste("API Error:", status_code(resp)))

data_json <- content(resp, as = "parsed", type = "application/json")
verification <- data_json$commit$verification

trusted_signer <- "Unknown / Unsigned"
gpg_status_text <- "Unverified"
gpg_color <- "firebrick"

if (!is.null(verification) && verification$verified == TRUE) {
  gpg_status_text <- "GPG VERIFIED"
  gpg_color <- "darkgreen"

  payload <- verification$payload
  match <- regexec("committer\\s+(.+?)\\s+<", payload)
  parts <- regmatches(payload, match)

  if (length(parts[[1]]) > 1) {
    trusted_signer <- parts[[1]][2]
  } else {
    trusted_signer <- "Signature is invalid"
  }
}

raw_url <- paste0("https://raw.githubusercontent.com/", gh_user, "/", gh_repo, "/", gh_commit, "/", gh_file)

result_data <- list(
  trusted_signer = trusted_signer,
  gpg_status_text = gpg_status_text,
  gpg_color = gpg_color,
  raw_url = raw_url,
  commit_author = data_json$commit$author$name,
  commit_hash = gh_commit,
  output_folder = output_folder
)

result_file <- file.path(output_folder, "verification_result.json")
write_json(result_data, result_file, auto_unbox = TRUE)

d_verified <- Dataset$with_context(ctx)$from_path(result_file,
  name = "GPG verification result",
  description = "GPG information"
)

verification_computation <- Computation$with_context(ctx)$new(
  name        = "Validate GitHub commit GPG",
  description = "Fetches commit from GitHub and verifies GPG signature status"
)$add_input_cid(
  d_params$cid
)$add_output_cid(
  d_verified$cid
)$finalize()

cat("Downloading data from: ", raw_url, "\n", sep = "")

local_path <- file.path(output_folder, "downloaded_data.csv")
download.file(raw_url, local_path, quiet = TRUE)

d_downloaded_csv <- Dataset$with_context(ctx)$from_path(local_path,
  name = "Downloaded CSV file",
  description = "CSV file downloaded from GitHub"
)

download_computation <- Computation$with_context(ctx)$new(
  name        = "Download CSV file",
  description = "Downloads the raw CSV data file from GitHub to local folder"
)$add_input_cid(
  d_verified$cid
)$add_output_cid(
  d_downloaded_csv$cid
)$finalize()

pop_data <- read.csv(local_path, sep = "", header = TRUE)

p <- ggplot(pop_data, aes(x = year, y = population)) +
  geom_line(color = "firebrick", linewidth = 1) +
  geom_point(color = "firebrick", size = 0.5, alpha = 0.5) +
  scale_y_continuous(labels = label_number(scale_cut = cut_short_scale())) +
  theme_minimal() +
  labs(
    title = "Global Population: 2000-2025",
    subtitle = paste0("Signed & Verified by: ", trusted_signer, "\n(Commit ", substr(gh_commit, 1, 7), ")"),
    caption = paste("Data Source: GitHub |", gpg_status_text),
    x = "Year",
    y = "Total Population"
  ) +
  annotate("text", x = min(pop_data$year), y = max(pop_data$population),
           label = paste(gpg_status_text, "\nSigner:", trusted_signer),
           hjust = 0, vjust = 1,
           color = gpg_color, size = 3.5, fontface = "bold")

output_filename <- file.path(output_folder, "verified_github_plot.jpg")
ggsave(output_filename, plot = p, width = 8, height = 5, dpi = 300)
cat("Plot saved to: ", output_filename, "\n", sep = "")

d_plot <- Dataset$with_context(ctx)$from_path(output_filename,
  name = "Population plot",
  description = "Graph of world population generated from CSV downloaded from GitHub"
)

plot_computation <- Computation$with_context(ctx)$new(
  name        = "Plot generation",
  description = "Generates annotated plot: Population 2000-2025"
)$add_input_cid(
  d_downloaded_csv$cid
)$add_output_cid(
  d_plot$cid
)$finalize()

# Export the context's statements and blobs to a manifest JSON file.
manifest_path <- integrity_path("output/manifest.json")
invisible(ctx$export(manifest_path))

cat("Manifest successfully generated and exported to output/manifest.json.\n")
