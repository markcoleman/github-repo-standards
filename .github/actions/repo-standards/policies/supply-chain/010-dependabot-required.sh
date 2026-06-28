#!/usr/bin/env bash
set -euo pipefail

check_name="Dependency update automation is present"
dependabot_path="${REQUIRED_DEPENDABOT_PATH:-.github/dependabot.yml}"

standards_require_non_empty_file "$check_name" "$dependabot_path" \
  "Expected $dependabot_path to configure dependency update automation." || return 0
standards_require_grep "$check_name" "$dependabot_path" \
  '^[[:space:]]*-?[[:space:]]*package-ecosystem:' \
  "$dependabot_path must include at least one package-ecosystem entry." || return 0

pass "$check_name" "$dependabot_path exists and declares dependency update coverage."
