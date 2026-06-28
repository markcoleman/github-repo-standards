#!/usr/bin/env bash
set -euo pipefail

check_name="Contributing guide is present"
contributing_path="${REQUIRED_CONTRIBUTING_PATH:-CONTRIBUTING.md}"

standards_require_non_empty_file "$check_name" "$contributing_path" \
  "Expected a root-level $contributing_path file with developer workflow guidance." || return 0

pass "$check_name" "$contributing_path exists and contains contributor guidance."
