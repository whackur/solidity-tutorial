#!/usr/bin/env bash
# Build every package and collect project-owned ABIs into a single tree.
#
# Output layout:
#   combined-out/<package>/<SourceFile.sol>/<ContractName>.json
#
# Only artifacts whose source lives under the package's src/, script/, or
# test/ directory are copied; forge-std/OZ/dependency ABIs are skipped.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$REPO_ROOT/combined-out"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

shopt -s nullglob
deploy_files=("$REPO_ROOT"/*/script/Deploy.s.sol)
shopt -u nullglob

if [[ ${#deploy_files[@]} -eq 0 ]]; then
  echo "[collect-abi] no script/Deploy.s.sol found under $REPO_ROOT/*/" >&2
  exit 1
fi

for deploy_file in "${deploy_files[@]}"; do
  pkg_dir=$(dirname "$(dirname "$deploy_file")")
  pkg=$(basename "$pkg_dir")

  echo "[collect-abi] >>> $pkg"
  (cd "$pkg_dir" && forge build >/dev/null)

  pkg_out_src="$pkg_dir/out"
  if [[ ! -d "$pkg_out_src" ]]; then
    echo "[collect-abi] WARN: $pkg has no out/ after build, skipping" >&2
    continue
  fi

  pkg_out_dst="$OUT_DIR/$pkg"
  mkdir -p "$pkg_out_dst"

  for dir in src script test; do
    [[ -d "$pkg_dir/$dir" ]] || continue
    while IFS= read -r sol_file; do
      sol_name=$(basename "$sol_file")
      artifact_dir="$pkg_out_src/$sol_name"
      [[ -d "$artifact_dir" ]] || continue
      cp -r "$artifact_dir" "$pkg_out_dst/"
    done < <(find "$pkg_dir/$dir" -type f -name "*.sol")
  done
done

echo "[collect-abi] done — combined ABIs at $OUT_DIR"
