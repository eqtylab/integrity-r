#!/usr/bin/env Rscript

sample_dependencies <- c(
  "ggplot2",
  "scales",
  "httr",
  "jsonlite",
  "ellmer"
)

installed <- rownames(installed.packages())
missing <- setdiff(sample_dependencies, installed)

if (length(missing) > 0L) {
  cat("Installing missing sample dependencies: ", paste(missing, collapse = ", "), "\n", sep = "")
  install.packages(missing, repos = "https://cloud.r-project.org")
} else {
  cat("All sample dependencies are already installed.\n")
}
