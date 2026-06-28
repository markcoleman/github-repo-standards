#!/usr/bin/env bash
set -euo pipefail

check_name="Contributing guide is present"
contributing_path="${REQUIRED_CONTRIBUTING_PATH:-CONTRIBUTING.md}"

if [[ ! -f "$contributing_path" ]]; then
  fail "$check_name" "Expected a root-level $contributing_path file with developer workflow guidance."
  return 0
fi

if [[ ! -s "$contributing_path" ]]; then
  fail "$check_name" "$contributing_path exists but is empty."
  return 0
fi

pass "$check_name" "$contributing_path exists and contains contributor guidance."
