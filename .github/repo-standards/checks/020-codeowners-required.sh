#!/usr/bin/env bash
set -euo pipefail

check_name="CODEOWNERS is present"
codeowners_paths=("CODEOWNERS" ".github/CODEOWNERS")
codeowners_file=""

for path in "${codeowners_paths[@]}"; do
  if [[ -f "$path" ]]; then
    codeowners_file="$path"
    break
  fi
done

if [[ -z "$codeowners_file" ]]; then
  fail "$check_name" "Expected CODEOWNERS or .github/CODEOWNERS."
  return 0
fi

if [[ ! -s "$codeowners_file" ]]; then
  fail "$check_name" "$codeowners_file exists but is empty."
  return 0
fi

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
