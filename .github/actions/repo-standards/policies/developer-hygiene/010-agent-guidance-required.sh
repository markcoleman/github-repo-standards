#!/usr/bin/env bash
set -euo pipefail

check_name="Agent guidance is present"
standards_select_non_empty_file "$check_name" \
  "Expected agent.md, AGENTS.md, or .github/AGENTS.md with AI agent guardrails." \
  "${REQUIRED_AGENT_GUIDE_PATH:-agent.md}" "AGENTS.md" ".github/AGENTS.md" || return 0
agent_file="$standards_selected_file"

pass "$check_name" "$agent_file exists and contains agent guardrails."
