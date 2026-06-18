# GitHub Repository Standards

Reusable GitHub Actions automation for lightweight repository standards. This repository provides a required-workflow entry point plus two local composite actions:

- `.github/actions/repo-standards` runs the configured standards checks and writes a Markdown summary.
- `.github/actions/repo-standards-comment` creates or updates one pull request status comment from that summary.

The bundled standards are intentionally small and broadly useful: every repository should have a non-empty root `README.md` and a populated `CODEOWNERS` file.

## What It Checks

The default check action validates:

- `README.md` exists at the repository root and contains content.
- `CODEOWNERS` or `.github/CODEOWNERS` exists and contains at least one owner entry.

The README path and minimum byte count are configurable through a simple data-only config file. The bundled defaults live in `.github/actions/repo-standards/config.env`.

## Reuse From Another Repository

Call the reusable workflow from a repository that should be validated:

```yaml
name: Required Repository Standards

on:
  pull_request:
  push:
    branches:
      - main

permissions:
  contents: read
  issues: write
  pull-requests: write

jobs:
  repo-standards:
    uses: OWNER/github-repo-standards/.github/workflows/repo-standards.yml@main
```

Replace `OWNER` with the account or organization that owns this repository.

The workflow checks out the target repository, checks out this standards repository from the same workflow ref, runs the bundled standards action, and optionally publishes a pull request comment.

## Workflow Inputs

The reusable workflow supports:

| Input | Default | Description |
| --- | --- | --- |
| `config-path` | `.github/repo-standards/config.env` | Optional caller repository config file. If the file is absent, bundled defaults are used. |
| `check-directory` | `''` | Optional caller repository directory containing additional `*.sh` checks. |
| `post-pr-comment` | `true` | Whether pull request runs should create or update the standards status comment. |

For compatibility with the previous workflow layout, `.github/repo-standards/checks` is automatically included when it exists in the caller repository, even when `check-directory` is not set.

## Add Repository-Specific Checks

Add executable shell scripts to the caller repository and pass their directory with `check-directory`:

```yaml
jobs:
  repo-standards:
    uses: OWNER/github-repo-standards/.github/workflows/repo-standards.yml@main
    with:
      check-directory: .github/repo-standards/checks
```

Checks are sourced in sorted order after the bundled checks. Each check can call:

```bash
pass "Check name" "Details"
fail "Check name" "Details"
```

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ -f "LICENSE" ]]; then
  pass "License is present" "LICENSE exists at the repository root."
else
  fail "License is present" "Add a root-level LICENSE file."
fi
```

Keep checks deterministic and dependency-free unless a standard truly needs extra tooling.

## Pull Request Comment

On pull requests, the workflow posts a single status comment marked with `<!-- repo-standards-status -->`. Later runs update that comment instead of creating duplicates. Set `post-pr-comment: false` to disable comment publishing while still running the checks and writing the GitHub Step Summary.

## Local Validation

Run the bundled checks locally from this repository:

```bash
.github/actions/repo-standards/validate-repo-standards.sh
```

Write the same Markdown summary used by GitHub Actions:

```bash
.github/actions/repo-standards/validate-repo-standards.sh --summary-file /tmp/repo-standards-summary.md
```

More detailed implementation notes live in `docs/repo-standards.md`.
