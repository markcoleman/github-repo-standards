# GitHub Repository Standards

Reusable GitHub Actions automation for lightweight repository standards. This repository provides a required-workflow entry point plus two local composite actions:

- `.github/actions/repo-standards` runs the configured standards checks and writes a Markdown summary.
- `.github/actions/repo-standards-comment` creates or updates one pull request status comment from that summary.
- `.github/workflows/standards-pages.yml` publishes the standards developer portal to GitHub Pages as static HTML.

The bundled standards are intentionally small and broadly useful: every repository should have clear documentation, review ownership, secure contribution paths, local hygiene rules, dependency automation, security analysis, and team or catalog metadata.

## What It Checks

The default check action validates:

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

## Developer Portal

The static developer portal lives in `docs/portal` and is published by the `Standards Developer Portal` workflow. The workflow builds a Pages artifact from the portal source, copies `README.md` and `docs/repo-standards.md` into `reference/`, and deploys the result with GitHub Pages.

Enable GitHub Pages for this repository with GitHub Actions as the source, then run the workflow from `main` or let it publish on the next matching push.
