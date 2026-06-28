#!/usr/bin/env bash
set -euo pipefail

check_name="Security analysis workflow is present"
workflow_path="${REQUIRED_SECURITY_ANALYSIS_WORKFLOW_PATH:-.github/workflows/security-analysis.yml}"

if [[ ! -f "$workflow_path" ]]; then
  fail "$check_name" "Expected $workflow_path to run CodeQL, Scorecard, or equivalent analysis."
  return 0
fi

if [[ ! -s "$workflow_path" ]]; then
  fail "$check_name" "$workflow_path exists but is empty."
  return 0
fi

if ! grep -Eiq 'codeql|scorecard|dependency-review|trivy|slsa|sarif' "$workflow_path"; then
  fail "$check_name" "$workflow_path should declare at least one recognizable security or supply-chain analyzer."
  return 0
fi

pass "$check_name" "$workflow_path exists and declares security or supply-chain analysis."
