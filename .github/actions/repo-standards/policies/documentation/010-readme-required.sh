#!/usr/bin/env bash
set -euo pipefail

check_name="Root README is present"
readme_path="${REQUIRED_README_PATH:-README.md}"
min_bytes="${MIN_README_BYTES:-1}"

if [[ ! -f "$readme_path" ]]; then
  fail "$check_name" "Expected a root-level $readme_path file."
  return 0
fi

if [[ ! -s "$readme_path" ]]; then
  fail "$check_name" "$readme_path exists but is empty."
  return 0
fi

byte_count="$(wc -c < "$readme_path" | tr -d '[:space:]')"
if (( byte_count < min_bytes )); then
  fail "$check_name" "$readme_path must contain at least $min_bytes bytes; found $byte_count."
fi

pass "$check_name" "$readme_path exists and contains content."
