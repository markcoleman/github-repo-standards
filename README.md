# GitHub Repository Standards

Reusable GitHub Actions automation for lightweight repository standards. This repository provides a required-workflow entry point plus two local composite actions:

- `.github/actions/repo-standards` runs categorized policy checks and writes a Markdown summary.
- `.github/actions/repo-standards-comment` creates or updates one pull request status comment from that summary.
- `.github/workflows/standards-pages.yml` publishes the standards developer portal to GitHub Pages as static HTML.
- `.github/workflows/release-on-pr-complete.yml` creates draft GitHub releases from completed pull requests with generated release notes.

The bundled standards are intentionally small and broadly useful: every repository should have clear documentation, review ownership, secure contribution paths, local hygiene rules, dependency automation, security analysis, and team or catalog metadata.

## What It Checks

The default policy action validates:

| Area | Required signal |
| --- | --- |
| Project entry point | Non-empty root `README.md`, with configurable path and minimum bytes. |
| Review routing | `CODEOWNERS` or `.github/CODEOWNERS` with at least one pattern and owner. |
| Repository guidance | Non-empty security, contributing, agent, and ignore files. |
| Dependency automation | `.github/dependabot.yml` with at least one `package-ecosystem`. |
| Security analysis | `.github/workflows/security-analysis.yml` naming CodeQL, OpenSSF Scorecard, SARIF upload, or equivalent analysis. |
| Ownership metadata | `ownership.yaml` or `catalog-info.yaml` identifying the responsible team or ownership source. |
| npm supply chain | Every detected npm project passes `tools/validate-npm-policy.mjs`. |

The README path, minimum byte count, policy file paths, security automation path, and ownership metadata path are configurable through a simple data-only config file. The bundled defaults live in `.github/actions/repo-standards/config.env`.

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

## Organization-Wide Required Workflow

For organization guardrails, keep the reusable workflow as one always-on required check and let the action report policy categories inside the summary. That keeps branch protection simple while giving developers a clear breakdown of documentation, identity, hygiene, security, and supply-chain failures.

GitHub.com reusable workflows expose `job.workflow_repository` and `job.workflow_sha`, which this workflow uses to check out the exact standards repository revision that supplied the called workflow. This makes the workflow safe to pin from many repositories without copying composite action code into each one.

To run only selected policy domains in a specialized organizational workflow, pass `policy-categories` as a comma-separated list:

```yaml
jobs:
  repo-standards:
    uses: OWNER/github-repo-standards/.github/workflows/repo-standards.yml@main
    with:
      policy-categories: documentation,security
```

Leave `policy-categories` empty, or set it to `all`, for the default full baseline.

All bundled policy items share the same `.github/actions/repo-standards` composite action and shell runner. The policy category folders only organize the checks; they do not duplicate workflow logic, checkout behavior, summary generation, or pull request comment handling.

## Workflow Inputs

The reusable workflow supports:

| Input | Default | Description |
| --- | --- | --- |
| `config-path` | `.github/repo-standards/config.env` | Optional caller repository config file. If the file is absent, bundled defaults are used. |
| `check-directory` | `''` | Optional caller repository directory containing additional `*.sh` checks. |
| `policy-categories` | `''` | Optional comma-separated list of bundled policy categories to run. Supported values are `documentation`, `repository-identity`, `developer-hygiene`, `security`, `supply-chain`, and `all`. Caller-specific `check-directory` checks still run when configured. |
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

Bundled checks are sourced by category, then caller-specific checks are reported under `Custom policies`. Each custom check can call:

```bash
pass "Check name" "Details"
fail "Check name" "Details"
standards_require_non_empty_file "Check name" "PATH" "Missing-file details"
```

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

check_name="License is present"
license_path="LICENSE"

standards_require_non_empty_file "$check_name" "$license_path" "Add a root-level LICENSE file." || return 0
pass "$check_name" "$license_path exists and contains content."
```

Keep checks deterministic and dependency-free unless a standard truly needs extra tooling.

## Security, Supply Chain, and Ownership Baselines

The repository includes GitHub-native platform configuration that consuming teams can adopt or adapt:

- Dependabot monitors GitHub Actions dependencies weekly through `.github/dependabot.yml`.
- The security analysis workflow runs CodeQL for portal JavaScript and OpenSSF Scorecard with SARIF upload on pull requests, pushes to `main`, a weekly schedule, and manual dispatch.
- `CODEOWNERS` remains the review-routing source of truth, while `ownership.yaml` adds team escalation metadata for humans and automation.
- `catalog-info.yaml` provides a Backstage-compatible component descriptor so a software catalog can discover the repository, owner, lifecycle, system, tags, and documentation link.

These files are intentionally simple examples. Organizations should replace placeholder owner/team values with real GitHub teams, security contacts, and catalog annotations before enforcing them broadly.


## Secure npm Package Manager Skeleton

A minimal npm example lives in `examples/npm-secure-skeleton`. It demonstrates a locked install flow and a small script that imports the local `@example/safe-greeter` package from `examples/safe-greeter`. The example is intentionally small so consumers can copy the pattern without adding unnecessary registry dependencies.

The skeleton demonstrates the npm project contract:

- commit `package.json`, `package-lock.json`, and the project `.npmrc`;
- install with `npm ci --ignore-scripts` through an `install:locked` script;
- pin registry dependencies exactly and keep lock-file declarations in sync;
- declare an npm engine and enforce the repository release cool-down policy;
- validate with `tools/validate-npm-policy.mjs`.

Use the example locally with:

```bash
cd examples/npm-secure-skeleton
npm run install:locked
npm start
cd ../..
node tools/validate-npm-policy.mjs examples/npm-secure-skeleton
```

When adding registry dependencies, wait until the version has satisfied the cool-down period in `.github/npm-supply-chain-policy.json`, pin the exact version in `package.json`, regenerate the lock file intentionally, and keep CI on `npm ci --ignore-scripts`.

The required standards workflow automatically detects npm projects by finding `package.json` files outside `node_modules` and applies the same validator to each project.

## Pull Request Comment

On pull requests, the workflow posts a single status comment marked with `<!-- repo-standards-status -->`. Later runs update that comment instead of creating duplicates. Set `post-pr-comment: false` to disable comment publishing while still running the checks and writing the GitHub Step Summary.

## Release on PR Complete

The repository includes an opt-in release workflow for teams that want a completed pull request to become a polished GitHub release. Add `release:patch`, `release:minor`, or `release:major` to a PR before merge. When the PR is merged to `main`, the workflow calculates the next semver tag from the previous published release, generates categorized notes with `.github/release.yml`, creates a draft release, and comments the release link back onto the PR.

Unlabeled PRs are skipped by default so routine changes do not create surprise releases. Consuming repositories can call the reusable workflow and set `default-bump: patch` when every completed PR should create a draft patch release.

```yaml
name: Release on PR Complete

on:
  pull_request:
    types:
      - closed
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    uses: OWNER/github-repo-standards/.github/workflows/release-on-pr-complete.yml@main
```

The generated release body starts with source PR, tag, previous release, compare range, and target commit metadata, followed by GitHub-generated release notes grouped into breaking changes, features, fixes, security, dependencies, documentation, developer experience, and other changes. See `docs/release-process.md` for the full label contract and workflow inputs.

## Local Validation

Run all bundled policy categories locally from this repository:

```bash
.github/actions/repo-standards/validate-repo-standards.sh
```

Run a focused category locally:

```bash
.github/actions/repo-standards/validate-repo-standards.sh --policy-category supply-chain
```

Write the same Markdown summary used by GitHub Actions:

```bash
.github/actions/repo-standards/validate-repo-standards.sh --summary-file /tmp/repo-standards-summary.md
```

More detailed implementation notes live in `docs/repo-standards.md`.

## Developer Portal

The static developer portal lives in `docs/portal` and is published by the `Standards Developer Portal` workflow. The workflow builds a Pages artifact from the portal source, copies `README.md` and `docs/repo-standards.md` into `reference/`, and deploys the result with GitHub Pages.

Enable GitHub Pages for this repository with GitHub Actions as the source, then run the workflow from `main` or let it publish on the next matching push.
