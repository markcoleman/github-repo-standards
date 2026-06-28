#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: .github/actions/repo-standards/validate-repo-standards.sh [options]

Options:
  --config PATH        Standards config file. Default: action-local config.env
  --policies PATH      Directory containing categorized policy check directories.
                       May be passed more than once. Default: action-local policies
  --policy-category ID Run only the named policy category. May be passed more than
                       once. Use directory names such as documentation or security.
  --checks PATH        Directory containing executable *.sh standards checks. May be
                       passed more than once. These are reported as custom policies.
  --summary-file PATH  Markdown summary output path. Default: stdout only
  -h, --help           Show this help message.
USAGE
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_path="$script_dir/config.env"
declare -a policy_roots=()
declare -a policy_categories=()
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

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

normalize_category() {
  local category
  category="$(trim "$1")"
  category="$(printf '%s' "$category" | tr '[:upper:]' '[:lower:]')"
  category="${category// /-}"
  category="${category//_/-}"
  printf '%s' "$category"
}

add_policy_category() {
  local raw_category normalized
  local -a raw_categories

  IFS=',' read -ra raw_categories <<< "$1"
  for raw_category in "${raw_categories[@]}"; do
    normalized="$(normalize_category "$raw_category")"
    if [[ -n "$normalized" && "$normalized" != "all" ]]; then
      policy_categories+=("$normalized")
    fi
  done
}

category_selected() {
  local category
  category="$(normalize_category "$1")"

  if [[ ${#policy_categories[@]} -eq 0 ]]; then
    return 0
  fi

  for selected_category in "${policy_categories[@]}"; do
    if [[ "$selected_category" == "$category" ]]; then
      return 0
    fi
  done

  return 1
}

category_display_name() {
  case "$(normalize_category "$1")" in
    documentation)
      printf 'Documentation policies'
      ;;
    repository-identity)
      printf 'Repository identity policies'
      ;;
    developer-hygiene)
      printf 'Developer hygiene policies'
      ;;
    security)
      printf 'Security policies'
      ;;
    supply-chain)
      printf 'Supply-chain policies'
      ;;
    custom)
      printf 'Custom policies'
      ;;
    *)
      local category title word first rest
      local -a words
      category="$(normalize_category "$1")"
      title=""
      IFS='-' read -ra words <<< "$category"
      for word in "${words[@]}"; do
        if [[ -n "$word" ]]; then
          first="$(printf '%s' "${word:0:1}" | tr '[:lower:]' '[:upper:]')"
          rest="${word:1}"
          title+="${first}${rest} "
        fi
      done
      printf '%s' "${title% } policies"
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      config_path="${2:-}"
      shift 2
      ;;
    --policies)
      policy_roots+=("${2:-}")
      shift 2
      ;;
    --policy-category)
      add_policy_category "${2:-}"
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

if [[ ${#policy_roots[@]} -eq 0 ]]; then
  policy_roots=("$script_dir/policies")
fi

declare -a results=()
failures=0
CURRENT_POLICY_CATEGORY="Uncategorized policies"

pass() {
  results+=("PASS|$CURRENT_POLICY_CATEGORY|$1|$2")
}

fail() {
  results+=("FAIL|$CURRENT_POLICY_CATEGORY|$1|$2")
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
policy_category_count=0
declare -a default_policy_order=(documentation repository-identity developer-hygiene security supply-chain)

run_policy_category_dir() {
  local policy_dir="$1"
  local policy_category category_check_count check

  policy_category="$(basename "$policy_dir")"
  if ! category_selected "$policy_category"; then
    return 0
  fi

  policy_category_count=$((policy_category_count + 1))
  CURRENT_POLICY_CATEGORY="$(category_display_name "$policy_category")"
  category_check_count=0

  while IFS= read -r check; do
    check_count=$((check_count + 1))
    category_check_count=$((category_check_count + 1))
    # shellcheck source=/dev/null
    source "$check"
  done < <(find "$policy_dir" -maxdepth 1 -type f -name '*.sh' | sort)

  if [[ "$category_check_count" -eq 0 ]]; then
    fail "$CURRENT_POLICY_CATEGORY configured" "No checks were found in $policy_dir."
  fi
}

for policy_root in "${policy_roots[@]}"; do
  if [[ ! -d "$policy_root" ]]; then
    echo "Standards policy directory not found: $policy_root" >&2
    exit 2
  fi

  for ordered_category in "${default_policy_order[@]}"; do
    if [[ -d "$policy_root/$ordered_category" ]]; then
      run_policy_category_dir "$policy_root/$ordered_category"
    fi
  done

  while IFS= read -r policy_dir; do
    policy_category="$(basename "$policy_dir")"
    known_category=0
    for ordered_category in "${default_policy_order[@]}"; do
      if [[ "$policy_category" == "$ordered_category" ]]; then
        known_category=1
        break
      fi
    done

    if [[ "$known_category" -eq 0 ]]; then
      run_policy_category_dir "$policy_dir"
    fi
  done < <(find "$policy_root" -mindepth 1 -maxdepth 1 -type d | sort)
done

if [[ "$policy_category_count" -eq 0 ]]; then
  if [[ ${#policy_categories[@]} -eq 0 ]]; then
    fail "Policy categories configured" "No policy categories were found in the configured policy directories."
  else
    fail "Policy categories configured" "None of the requested policy categories were found: ${policy_categories[*]}."
  fi
fi

if [[ ${#checks_dirs[@]} -gt 0 ]]; then
  for checks_dir in "${checks_dirs[@]}"; do
    if [[ ! -d "$checks_dir" ]]; then
      echo "Standards check directory not found: $checks_dir" >&2
      exit 2
    fi

    CURRENT_POLICY_CATEGORY="$(category_display_name custom)"
    while IFS= read -r check; do
      check_count=$((check_count + 1))
      # shellcheck source=/dev/null
      source "$check"
    done < <(find "$checks_dir" -maxdepth 1 -type f -name '*.sh' | sort)
  done
fi

if [[ "$check_count" -eq 0 ]]; then
  fail "Standards checks configured" "No standards checks were found in the configured check directories."
fi

summary="$(
  cat <<SUMMARY
## Repository Standards

| Status | Policy category | Check | Details |
| --- | --- | --- | --- |
SUMMARY

  for result in "${results[@]}"; do
    IFS='|' read -r status category name details <<< "$result"
    if [[ "$status" == "PASS" ]]; then
      echo "| PASS | $category | $name | $details |"
    else
      echo "| FAIL | $category | $name | $details |"
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
