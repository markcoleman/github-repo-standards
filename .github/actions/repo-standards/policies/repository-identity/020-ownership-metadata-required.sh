#!/usr/bin/env bash
set -euo pipefail

check_name="Ownership metadata is present"
standards_select_non_empty_file "$check_name" \
  "Expected ownership.yaml or catalog-info.yaml to document team ownership metadata." \
  "${REQUIRED_OWNERSHIP_METADATA_PATH:-ownership.yaml}" "catalog-info.yaml" || return 0
ownership_file="$standards_selected_file"

standards_require_grep_i "$check_name" "$ownership_file" \
  'owner|primaryOwner|codeOwnersFile' \
  "$ownership_file should identify an owning team or ownership source." || return 0

pass "$check_name" "$ownership_file exists and identifies repository ownership metadata."
