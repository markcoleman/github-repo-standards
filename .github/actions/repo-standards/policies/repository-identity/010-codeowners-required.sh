#!/usr/bin/env bash
set -euo pipefail

check_name="CODEOWNERS is present"
standards_select_non_empty_file "$check_name" "Expected CODEOWNERS or .github/CODEOWNERS." \
  "CODEOWNERS" ".github/CODEOWNERS" || return 0
codeowners_file="$standards_selected_file"

if ! awk '
  /^[[:space:]]*#/ { next }
  /^[[:space:]]*$/ { next }
  NF >= 2 { found = 1 }
  END { exit found ? 0 : 1 }
' "$codeowners_file"; then
  fail "$check_name" "$codeowners_file must include at least one pattern and owner entry."
  return 0
fi

pass "$check_name" "$codeowners_file exists and includes at least one owner entry."
