#!/usr/bin/env bash
set -euo pipefail

check_name="Security policy is present"
security_path="${REQUIRED_SECURITY_PATH:-SECURITY.md}"

standards_require_non_empty_file "$check_name" "$security_path" \
  "Expected a root-level $security_path file with vulnerability reporting guidance." || return 0

pass "$check_name" "$security_path exists and contains security reporting guidance."
