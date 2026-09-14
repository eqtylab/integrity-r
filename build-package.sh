#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_dir="${project_dir}/package"
man_dir="${package_dir}/man"
dist_dir="${project_dir}/dist"

check_args=("--as-cran")

cd "${project_dir}"

if [[ "${1:-}" == "--no-manual" ]]; then
  check_args+=("--no-manual")
  shift
fi

if [[ "$#" -ne 0 ]]; then
  echo "Usage: ./build-package.sh [--no-manual]" >&2
  exit 2
fi

command -v R >/dev/null 2>&1 || {
  echo "R is required to build the package." >&2
  exit 1
}

command -v Rscript >/dev/null 2>&1 || {
  echo "Rscript is required to generate the package documentation." >&2
  exit 1
}

rm -rf "${man_dir}"
mkdir -p "${man_dir}"

Rscript --vanilla -e '
  if (!requireNamespace("roxygen2", quietly = TRUE)) {
    stop("Install the build dependency with install.packages(\"roxygen2\").", call. = FALSE)
  }
  roxygen2::roxygenise("package", roclets = "rd")
'

if ! compgen -G "${man_dir}/*.Rd" >/dev/null; then
  echo "Documentation generation produced no package/man/*.Rd files." >&2
  exit 1
fi

package_name="$(Rscript --vanilla -e 'cat(read.dcf("package/DESCRIPTION")[1, "Package"])')"
package_version="$(Rscript --vanilla -e 'cat(read.dcf("package/DESCRIPTION")[1, "Version"])')"
tarball="${package_name}_${package_version}.tar.gz"
check_dir="${dist_dir}/${package_name}.Rcheck"

mkdir -p "${dist_dir}"
rm -rf "${check_dir}"

(
  cd "${dist_dir}"
  R CMD build "${package_dir}"
)

if [[ ! -f "${dist_dir}/${tarball}" ]]; then
  echo "Expected source package was not created: ${dist_dir}/${tarball}" >&2
  exit 1
fi

(
  cd "${dist_dir}"
  R CMD check "${check_args[@]}" "${tarball}"
)

if grep -Eq '^Status:.*(ERROR|WARNING)' "${check_dir}/00check.log"; then
  echo "R CMD check reported an error or warning." >&2
  exit 1
fi

echo "Source package: ${dist_dir}/${tarball}"
echo "Check results:  ${check_dir}"
