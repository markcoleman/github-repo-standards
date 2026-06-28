#!/usr/bin/env bash
set -euo pipefail

check_name="Git ignore rules are present"
gitignore_path="${REQUIRED_GITIGNORE_PATH:-.gitignore}"

standards_require_non_empty_file "$check_name" "$gitignore_path" \
  "Expected a root-level $gitignore_path file to keep local and generated artifacts out of commits." || return 0

pass "$check_name" "$gitignore_path exists and contains ignore rules."
