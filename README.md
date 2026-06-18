# GitHub Repository Standards

This repository provides a small, reusable GitHub Actions workflow for repository standards. The initial standards require a non-empty `README.md` and a populated `CODEOWNERS` file, because repositories need both clear documentation and clear ownership.

The workflow is intentionally lightweight:

- It runs in Bash with no package installation.
- It can run on pull requests, pushes to `main`, or as a reusable workflow through `workflow_call`.
- It writes a GitHub Step Summary for every run.
- It creates or updates one readable pull request comment with the current standards status.
- Its bundled checks live in a self-contained composite action under `.github/actions/repo-standards`.

## Local Validation

Run the same checks locally before opening a pull request:

```bash
.github/actions/repo-standards/validate-repo-standards.sh
```

To write the same Markdown summary used by the workflow:

```bash
.github/actions/repo-standards/validate-repo-standards.sh --summary-file /tmp/repo-standards-summary.md
```

## Reuse From Another Repository

Add this workflow as a required reusable workflow from another repository:

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

Replace `OWNER` with the organization or account that owns this repository.

The workflow checks out the target repository, checks out the standards action from the same ref as the reusable workflow, and then runs the shared composite action.

## Extending Standards

For this repository, add a new bundled `*.sh` file in `.github/actions/repo-standards/checks`. Checks are sourced in sorted order and can call:

- `pass "Check name" "Details"`
- `fail "Check name" "Details"`

Keep checks deterministic and dependency-free unless a standard truly requires extra tooling.

Bundled default configuration lives in `.github/actions/repo-standards/config.env`. It supports simple `KEY=value` lines and comments. It does not evaluate shell commands.

Consuming repositories can add their own checks by passing `check-directory`:

```yaml
jobs:
  repo-standards:
    uses: OWNER/github-repo-standards/.github/workflows/repo-standards.yml@main
    with:
      check-directory: .github/repo-standards/checks
```

The bundled action, default config, and default checks come from this repository; callers only need to provide repository-specific check directories or config overrides when they want to extend the defaults.

## Pull Request Visibility

On pull requests, the workflow posts a visual status comment marked with an internal `repo-standards-status` marker. Later runs update that same comment instead of creating duplicates, so reviewers see the latest status without noise.
