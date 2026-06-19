# GitHub Repository Standards

Reusable GitHub Actions automation for lightweight repository standards. This repository provides a required-workflow entry point plus two local composite actions:

- `.github/actions/repo-standards` runs the configured standards checks and writes a Markdown summary.
- `.github/actions/repo-standards-comment` creates or updates one pull request status comment from that summary.
- `.github/workflows/standards-pages.yml` publishes the standards developer portal to GitHub Pages as static HTML.

The bundled standards are intentionally small and broadly useful: every repository should have a non-empty root `README.md`, a populated `CODEOWNERS` file, security reporting guidance, contributor workflow documentation, AI agent guardrails, root ignore rules for local/generated artifacts, dependency update automation, security/supply-chain analysis, and ownership/catalog metadata.

## What It Checks

The default check action validates:

- `README.md` exists at the repository root and contains content.
- `CODEOWNERS` or `.github/CODEOWNERS` exists and contains at least one owner entry.
- `SECURITY.md` exists at the repository root and documents vulnerability reporting expectations.
- `CONTRIBUTING.md` exists at the repository root and documents developer workflow expectations.
- `agent.md`, `AGENTS.md`, or `.github/AGENTS.md` exists and documents AI agent guardrails.
- `.gitignore` exists at the repository root and contains ignore rules for local/generated artifacts.
- `.github/dependabot.yml` exists and declares dependency update automation coverage.
- `.github/workflows/security-analysis.yml` exists and runs CodeQL, OpenSSF Scorecard, SARIF upload, or equivalent supply-chain analysis.
- `ownership.yaml` or `catalog-info.yaml` exists and identifies repository ownership metadata for teams and portals.

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

## Security, Supply Chain, and Ownership Baselines

The repository includes GitHub-native platform configuration that consuming teams can adopt or adapt:

- Dependabot monitors GitHub Actions dependencies weekly through `.github/dependabot.yml`.
- The security analysis workflow runs CodeQL for portal JavaScript and OpenSSF Scorecard with SARIF upload on pull requests, pushes to `main`, a weekly schedule, and manual dispatch.
- `CODEOWNERS` remains the review-routing source of truth, while `ownership.yaml` adds team escalation metadata for humans and automation.
- `catalog-info.yaml` provides a Backstage-compatible component descriptor so a software catalog can discover the repository, owner, lifecycle, system, tags, and documentation link.

These files are intentionally simple examples. Organizations should replace placeholder owner/team values with real GitHub teams, security contacts, and catalog annotations before enforcing them broadly.


## Secure npm Package Manager Skeleton

A minimal npm example lives in `examples/npm-secure-skeleton`. It demonstrates a locked install flow and a small script that imports the local `@example/safe-greeter` package from `examples/safe-greeter`. The example is intentionally small so consumers can copy the pattern without adding unnecessary registry dependencies.

Supply-chain controls in the skeleton include:

- a committed `package-lock.json`;
- a project `.npmrc` with `package-lock=true`, `save-exact=true`, and `ignore-scripts=true`;
- an `install:locked` script that runs `npm ci --ignore-scripts` so installs fail rather than update the lock file;
- a repository policy file at `.github/npm-supply-chain-policy.json` requiring a seven-day dependency cool-down period for newly selected registry versions;
- `tools/validate-npm-policy.mjs`, which checks that the lock file, npm config, locked install command, exact dependency convention, and policy settings remain in place.

Use the example locally with:

```bash
cd examples/npm-secure-skeleton
npm run install:locked
npm start
cd ../..
node tools/validate-npm-policy.mjs examples/npm-secure-skeleton
```

When adding registry dependencies, wait until the version has satisfied the cool-down period in `.github/npm-supply-chain-policy.json`, pin the exact version in `package.json`, regenerate the lock file intentionally, and keep automation on `npm ci --ignore-scripts` instead of `npm install`.

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
