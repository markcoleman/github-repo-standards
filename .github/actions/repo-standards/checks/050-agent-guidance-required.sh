#!/usr/bin/env bash
set -euo pipefail

check_name="Agent guidance is present"
agent_paths=("${REQUIRED_AGENT_GUIDE_PATH:-agent.md}" "AGENTS.md" ".github/AGENTS.md")
agent_file=""

for path in "${agent_paths[@]}"; do
  if [[ -f "$path" ]]; then
    agent_file="$path"
    break
  fi
done

if [[ -z "$agent_file" ]]; then
  fail "$check_name" "Expected agent.md, AGENTS.md, or .github/AGENTS.md with AI agent guardrails."
  return 0
fi

if [[ ! -s "$agent_file" ]]; then
  fail "$check_name" "$agent_file exists but is empty."
  return 0
fi

pass "$check_name" "$agent_file exists and contains agent guardrails."
