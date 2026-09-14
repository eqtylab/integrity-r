#!/usr/bin/env bash

set -euo pipefail

if ! command -v Rscript >/dev/null 2>&1; then
  printf 'Error: R is not installed or Rscript is not available on PATH.\n' >&2
  exit 127
fi

sample_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

printf '\nChecking optional sample dependencies\n'
Rscript "$sample_root/install-dependencies.R"

run_sample() {
  sample_folder=$1
  shift
  sample_script=$1
  shift

  printf '\nRunning %s/%s\n' "$sample_folder" "$sample_script"
  (
    cd "$sample_root/$sample_folder"
    Rscript "$sample_script" "$@"
  )
}

run_sample "01-basic-sample" "sample-register.R"
run_sample "02-all-nodes" "sample-all-nodes.R"
run_sample "03-time-lineage" "sample-history.R"
run_sample "04-plot" "sample-verifiable-plot.R"
run_sample "05-plot-validation" "generate-verifiable-plot-gitcommit.R"
run_sample "06-adsl-t14-qc-agent" "sample_01_adsl_qc_agent.R"
run_sample "06-adsl-t14-qc-agent" "sample_02_t14_2_01_agent.R"
run_sample "06-adsl-t14-qc-agent" "sample_03_merge.R" \
  "output/manifest-adsl.json" \
  "output/manifest-t14-2-01.json"

printf '\nAll samples completed successfully.\n'
