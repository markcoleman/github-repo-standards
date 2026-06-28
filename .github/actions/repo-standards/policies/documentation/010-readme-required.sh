#!/usr/bin/env bash
set -euo pipefail

check_name="Root README is present"
readme_path="${REQUIRED_README_PATH:-README.md}"
min_bytes="${MIN_README_BYTES:-1}"

standards_require_non_empty_file "$check_name" "$readme_path" "Expected a root-level $readme_path file." || return 0
standards_require_min_bytes "$check_name" "$readme_path" "$min_bytes" || return 0

pass "$check_name" "$readme_path exists and contains content."
