#!/usr/bin/env bash
set -euo pipefail

check_name="Security policy is present"
security_path="${REQUIRED_SECURITY_PATH:-SECURITY.md}"

if [[ ! -f "$security_path" ]]; then
  fail "$check_name" "Expected a root-level $security_path file with vulnerability reporting guidance."
  return 0
fi

if [[ ! -s "$security_path" ]]; then
  fail "$check_name" "$security_path exists but is empty."
  return 0
fi

pass "$check_name" "$security_path exists and contains security reporting guidance."
