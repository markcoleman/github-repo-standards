#!/usr/bin/env bash
set -euo pipefail

check_name="Git ignore rules are present"
gitignore_path="${REQUIRED_GITIGNORE_PATH:-.gitignore}"

if [[ ! -f "$gitignore_path" ]]; then
  fail "$check_name" "Expected a root-level $gitignore_path file to keep local and generated artifacts out of commits."
  return 0
fi

if [[ ! -s "$gitignore_path" ]]; then
  fail "$check_name" "$gitignore_path exists but is empty."
  return 0
fi

pass "$check_name" "$gitignore_path exists and contains ignore rules."
