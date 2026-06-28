#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: .github/actions/repo-standards/validate-repo-standards.sh [options]

Options:
  --config PATH        Standards config file. Default: action-local config.env
  --checks PATH        Directory containing executable *.sh standards checks. May be
                       passed more than once. Default: action-local checks
  --summary-file PATH  Markdown summary output path. Default: stdout only
  -h, --help           Show this help message.
USAGE
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_path="$script_dir/config.env"
declare -a checks_dirs=()
summary_file=""

load_config() {
  local line key value

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"

    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    if [[ ! "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      echo "Invalid config line in $config_path: $line" >&2
      exit 2
    fi

    key="${line%%=*}"
    value="${line#*=}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    export "$key=$value"
  done < "$config_path"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      config_path="${2:-}"
      shift 2
      ;;
    --checks)
      checks_dirs+=("${2:-}")
      shift 2
      ;;
    --summary-file)
      summary_file="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -n "$config_path" && -f "$config_path" ]]; then
  load_config
fi

if [[ ${#checks_dirs[@]} -eq 0 ]]; then
  checks_dirs=("$script_dir/checks")
fi

declare -a results=()
failures=0

pass() {
  results+=("PASS|$1|$2")
}

fail() {
  results+=("FAIL|$1|$2")
  failures=$((failures + 1))
}

standards_require_non_empty_file() {
  local check_name="$1"
  local file_path="$2"
  local missing_details="$3"

  if [[ ! -f "$file_path" ]]; then
    fail "$check_name" "$missing_details"
    return 1
  fi

  if [[ ! -s "$file_path" ]]; then
    fail "$check_name" "$file_path exists but is empty."
    return 1
  fi

  return 0
}

standards_selected_file=""
standards_select_non_empty_file() {
  local check_name="$1"
  local missing_details="$2"
  local file_path
  standards_selected_file=""
  shift 2

  for file_path in "$@"; do
    if [[ -f "$file_path" ]]; then
      standards_selected_file="$file_path"
      standards_require_non_empty_file "$check_name" "$file_path" "$missing_details"
      return $?
    fi
  done

  fail "$check_name" "$missing_details"
  return 1
}

standards_require_min_bytes() {
  local check_name="$1"
  local file_path="$2"
  local min_bytes="$3"
  local byte_count

  byte_count="$(wc -c < "$file_path" | tr -d '[:space:]')"
  if (( byte_count < min_bytes )); then
    fail "$check_name" "$file_path must contain at least $min_bytes bytes; found $byte_count."
    return 1
  fi

  return 0
}

standards_require_grep() {
  local check_name="$1"
  local file_path="$2"
  local pattern="$3"
  local failure_details="$4"

  if ! grep -Eq "$pattern" "$file_path"; then
    fail "$check_name" "$failure_details"
    return 1
  fi

  return 0
}

standards_require_grep_i() {
  local check_name="$1"
  local file_path="$2"
  local pattern="$3"
  local failure_details="$4"

  if ! grep -Eiq "$pattern" "$file_path"; then
    fail "$check_name" "$failure_details"
    return 1
  fi

  return 0
}

export -f pass
export -f fail

check_count=0
for checks_dir in "${checks_dirs[@]}"; do
  if [[ ! -d "$checks_dir" ]]; then
    echo "Standards check directory not found: $checks_dir" >&2
    exit 2
  fi

  while IFS= read -r check; do
    check_count=$((check_count + 1))
    # shellcheck source=/dev/null
    source "$check"
  done < <(find "$checks_dir" -maxdepth 1 -type f -name '*.sh' | sort)
done

if [[ "$check_count" -eq 0 ]]; then
  fail "Standards checks configured" "No standards checks were found in the configured check directories."
fi

summary="$(
  cat <<SUMMARY
## Repository Standards

| Status | Check | Details |
| --- | --- | --- |
SUMMARY

  for result in "${results[@]}"; do
    IFS='|' read -r status name details <<< "$result"
    if [[ "$status" == "PASS" ]]; then
      echo "| PASS | $name | $details |"
    else
      echo "| FAIL | $name | $details |"
    fi
  done

  echo
  if [[ "$failures" -eq 0 ]]; then
    echo "All repository standards checks passed."
  else
    echo "$failures repository standards check(s) failed."
  fi
)"

echo "$summary"

if [[ -n "$summary_file" ]]; then
  printf '%s\n' "$summary" > "$summary_file"
fi

if [[ "$failures" -eq 0 ]]; then
  exit 0
fi

exit 1
