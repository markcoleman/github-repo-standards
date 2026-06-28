#!/usr/bin/env bash
set -euo pipefail

check_name="Security analysis workflow is present"
workflow_path="${REQUIRED_SECURITY_ANALYSIS_WORKFLOW_PATH:-.github/workflows/security-analysis.yml}"

standards_require_non_empty_file "$check_name" "$workflow_path" \
  "Expected $workflow_path to run CodeQL, Scorecard, or equivalent analysis." || return 0
standards_require_grep_i "$check_name" "$workflow_path" \
  'codeql|scorecard|dependency-review|trivy|slsa|sarif' \
  "$workflow_path should declare at least one recognizable security or supply-chain analyzer." || return 0

pass "$check_name" "$workflow_path exists and declares security or supply-chain analysis."
