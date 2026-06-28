#!/usr/bin/env bash
set -euo pipefail

check_name="Ownership metadata is present"
ownership_paths=("${REQUIRED_OWNERSHIP_METADATA_PATH:-ownership.yaml}" "catalog-info.yaml")
ownership_file=""

for path in "${ownership_paths[@]}"; do
  if [[ -f "$path" ]]; then
    ownership_file="$path"
    break
  fi
done

if [[ -z "$ownership_file" ]]; then
  fail "$check_name" "Expected ownership.yaml or catalog-info.yaml to document team ownership metadata."
  return 0
fi

if [[ ! -s "$ownership_file" ]]; then
  fail "$check_name" "$ownership_file exists but is empty."
  return 0
fi

if ! grep -Eiq 'owner|primaryOwner|codeOwnersFile' "$ownership_file"; then
  fail "$check_name" "$ownership_file should identify an owning team or ownership source."
  return 0
fi

pass "$check_name" "$ownership_file exists and identifies repository ownership metadata."
