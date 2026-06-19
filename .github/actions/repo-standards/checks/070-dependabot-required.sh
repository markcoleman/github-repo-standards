#!/usr/bin/env bash
set -euo pipefail

check_name="Dependency update automation is present"
dependabot_path="${REQUIRED_DEPENDABOT_PATH:-.github/dependabot.yml}"

if [[ ! -f "$dependabot_path" ]]; then
  fail "$check_name" "Expected $dependabot_path to configure dependency update automation."
  return 0
fi

if [[ ! -s "$dependabot_path" ]]; then
  fail "$check_name" "$dependabot_path exists but is empty."
  return 0
fi

if ! grep -Eq '^[[:space:]]*-?[[:space:]]*package-ecosystem:' "$dependabot_path"; then
  fail "$check_name" "$dependabot_path must include at least one package-ecosystem entry."
  return 0
fi

pass "$check_name" "$dependabot_path exists and declares dependency update coverage."
