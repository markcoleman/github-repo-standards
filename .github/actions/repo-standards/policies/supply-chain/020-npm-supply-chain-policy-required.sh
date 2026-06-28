#!/usr/bin/env bash
set -euo pipefail

npm_projects=()
while IFS= read -r package_file; do
  npm_projects+=("$package_file")
done < <(
  find . \
    -path './.git' -prune -o \
    -path './node_modules' -prune -o \
    -path '*/node_modules' -prune -o \
    -name package.json -type f -print | sort
)

if [[ ${#npm_projects[@]} -eq 0 ]]; then
  pass "npm supply-chain policy" "No package.json files were detected."
  return 0
fi

failed_projects=()
validator="${GITHUB_ACTION_PATH:-.github/actions/repo-standards}/../../../tools/validate-npm-policy.mjs"
validator="$(cd "$(dirname "$validator")" && pwd)/$(basename "$validator")"

for package_file in "${npm_projects[@]}"; do
  project_dir="${package_file%/package.json}"
  if ! node "$validator" "$project_dir" >/tmp/npm-policy-validation.log 2>&1; then
    failed_projects+=("${project_dir#./}")
  fi
done

if [[ ${#failed_projects[@]} -eq 0 ]]; then
  pass "npm supply-chain policy" "Validated ${#npm_projects[@]} npm project(s) for lock files, locked installs, cool-down policy, and npm hardening settings."
else
  fail "npm supply-chain policy" "Non-compliant npm project(s): ${failed_projects[*]}. Run node $validator <project-dir> for details."
fi
