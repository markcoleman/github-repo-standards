# Repository Standards Workflow

## Purpose

Repository standards make basic project expectations visible, automated, and consistent. The bundled rules stay deliberately small: documentation, ownership, local hygiene, security automation, and npm supply-chain controls.

Each rule favors a concrete signal over broad process language. Together they give contributors and maintainers one reliable place to understand:

- what the repository contains,
- how to build or validate it,
- who owns review and escalation,
- where deeper documentation lives.

## Rule Summary

| Check | Required signal | Distinct validation |
| --- | --- | --- |
| Root README | `README.md` by default | File exists, is non-empty, and meets `MIN_README_BYTES`. |
| CODEOWNERS | `CODEOWNERS` or `.github/CODEOWNERS` | At least one non-comment entry includes a pattern and owner. |
| Security policy | `SECURITY.md` by default | File exists and is non-empty. |
| Contributing guide | `CONTRIBUTING.md` by default | File exists and is non-empty. |
| Agent guidance | `agent.md`, `AGENTS.md`, or `.github/AGENTS.md` | File exists and is non-empty. |
| Git ignore rules | `.gitignore` by default | File exists and is non-empty. |
| Dependency updates | `.github/dependabot.yml` by default | File exists, is non-empty, and declares a `package-ecosystem`. |
| Security analysis | `.github/workflows/security-analysis.yml` by default | File exists, is non-empty, and names a recognizable analyzer such as CodeQL, OpenSSF Scorecard, dependency review, Trivy, SLSA, or SARIF upload. |
| Ownership metadata | `ownership.yaml` or `catalog-info.yaml` by default | File exists, is non-empty, and identifies an owner or ownership source. |
| npm supply-chain policy | Each detected npm project | Every `package.json` outside `.git` and `node_modules` passes `tools/validate-npm-policy.mjs`. |

## Root README

The path and minimum byte count are configurable in the bundled action config at `.github/actions/repo-standards/config.env`, or by passing a repository-specific config file through the reusable workflow. The policy-file checks also support path overrides for security, contributing, agent guidance, and ignore files. The config file supports simple `KEY=value` lines and comments; it is parsed as data instead of evaluated as shell.

## CODEOWNERS

Ownership metadata helps reviewers, maintainers, and automation understand who is responsible for changes across the repository.

## Security Policy

Security policy documentation is a guardrail for incident response. It prevents contributors from disclosing sensitive findings in public issues and gives maintainers a single place to document secure development expectations such as least-privilege automation, secret rotation, dependency hygiene, and ownership of security-sensitive files.

## Contributing Guide

Contributor documentation improves developer experience by making setup, validation, pull request expectations, documentation updates, screenshots, and review handoffs explicit. A healthy repository should not rely on tribal knowledge for routine contributions.

## Agent Guidance

Agent guidance documents how automated coding agents should work in the repository. It should describe preserved design intent, validation commands, documentation expectations, generated-artifact rules, and repository-specific constraints. This keeps future agent contributions aligned with maintainers instead of leaving agents to infer policy from existing files alone.

## Root Git Ignore

Ignore rules are a lightweight control for repository hygiene. They reduce accidental commits of local caches, editor state, build output, test artifacts, agent scratch files, and other generated files that should not become long-lived source artifacts.

## Dependency Update Automation

For this repository the Dependabot baseline covers GitHub Actions updates weekly, which keeps reusable workflow dependencies visible to maintainers.

## Security and Supply Chain Analysis

This repository includes CodeQL analysis for the portal JavaScript and OpenSSF Scorecard results uploaded as SARIF.

Recommended GitHub platform controls to pair with the workflow include:

- secret scanning and push protection,
- Dependabot alerts and security updates,
- branch protection or rulesets that require standards and security checks,
- least-privilege workflow permissions,
- reviewed third-party actions and pinned action upgrade ownership.

## Ownership Metadata

`CODEOWNERS` routes review requests, while ownership metadata records human and platform context such as the owning team, security contact, escalation channel, service tier, system, lifecycle, and catalog annotations.

This repository includes both:

- `ownership.yaml` for repository governance and team escalation metadata,
- `catalog-info.yaml` as a Backstage-compatible `Component` descriptor for software catalog ingestion.

## npm Supply-Chain Policy

The standards check detects npm projects by finding `package.json` files outside `.git` and `node_modules`. When any npm project is present, every detected project must pass `tools/validate-npm-policy.mjs`.

The npm project contract is:

- a committed `package-lock.json` with a modern lockfile version and a root package entry;
- a project `.npmrc` with `package-lock=true`, `save-exact=true`, `ignore-scripts=true`, `audit=true`, and `fund=false`;
- a package script named `install:locked` that runs `npm ci --ignore-scripts`;
- exact registry versions in `dependencies`, `devDependencies`, and `optionalDependencies`, while allowing local and alias specifications such as `file:`, `workspace:`, `link:`, and `npm:`;
- lock-file dependency declarations that match `package.json`;
- an `engines.npm` declaration so contributors and automation use a known npm baseline;
- a repository policy at `.github/npm-supply-chain-policy.json` that requires a dependency release cool-down, lock-file usage, exact registry versions, disabled install scripts by default, npm audit, and disabled funding prompts.

This rule keeps npm installs reproducible: required workflows must use `npm ci --ignore-scripts`, which installs only the package set and versions represented in the committed lock file and fails instead of rewriting dependency resolution.

## Secure npm Package Manager Skeleton

The repository includes a minimal npm skeleton under `examples/npm-secure-skeleton` and a local package under `examples/safe-greeter`. The sample application imports `@example/safe-greeter` from the locked dependency tree and can be run with `npm start` after a locked install.

Use the skeleton as a copyable example of the npm project contract above. It commits the package manifest, lock file, and `.npmrc`; installs with `npm ci --ignore-scripts`; and validates with:

```bash
node tools/validate-npm-policy.mjs examples/npm-secure-skeleton
```

The validation script is intentionally dependency-free. It verifies the policy file, required npm settings, locked install command, exact dependency specs for registry dependencies, and consistency between `package.json` and `package-lock.json`.

To refresh the skeleton intentionally, update `package.json`, regenerate the lock file with `npm install --package-lock-only --ignore-scripts`, inspect the diff, run `npm run install:locked`, run `npm start`, and run the validator. Do not replace the locked install flow with `npm install` in CI or required workflows.

## Developer Experience

The workflow is designed to be quick and predictable:

- no dependency installation,
- no package registry calls,
- one shell runner for categorized policy checks,
- categorized policy folders discovered from the checked-out standards repository,
- short timeout,
- clear Markdown output locally and in GitHub Actions.

## Developer Portal Publishing

This repository includes a static developer portal at `docs/portal`. The portal is designed as the first stop for engineers adopting the standards workflow: it explains the default checks, shows reusable workflow snippets, maps the automation flow, and links back to the Markdown reference docs.

The `Standards Developer Portal` workflow at `.github/workflows/standards-pages.yml` publishes the portal to GitHub Pages. It:

- checks out the repository,
- configures GitHub Pages,
- copies `docs/portal` into a `_site` artifact,
- copies `README.md` and this file into `_site/reference`,
- uploads the Pages artifact,
- deploys the static site through `actions/deploy-pages`.

Enable GitHub Pages with GitHub Actions as the source before relying on automatic publication.

## Required Workflow Adoption

Repository administrators can add this workflow as a required workflow in GitHub branch protection or rulesets after referencing it from each repository. The workflow supports `workflow_call`, which makes the standards implementation reusable while still allowing each consuming repository to decide when it runs.

Example:

```yaml
jobs:
  repo-standards:
    uses: OWNER/github-repo-standards/.github/workflows/repo-standards.yml@main
```

The workflow checks out the target repository, checks out this repository's standards actions from the same ref as the reusable workflow, then runs the shared check action at `.github/actions/repo-standards`. Repositories that call this workflow through `workflow_call` only need to provide repository-specific check directories or config overrides when they want to extend the bundled defaults.

The default organizational baseline runs every bundled policy category. Specialized required workflows can target a smaller slice:

```yaml
jobs:
  documentation-and-security:
    uses: OWNER/github-repo-standards/.github/workflows/repo-standards.yml@main
    with:
      policy-categories: documentation,security
```

Supported category identifiers are `documentation`, `repository-identity`, `developer-hygiene`, `security`, `supply-chain`, and `all`. Empty input is the same as `all`. Caller-specific `check-directory` scripts still run whenever they are configured, even when a bundled category subset is selected.

## Pull Request Comment Behavior

The workflow uses the shared comment action at `.github/actions/repo-standards-comment` to post a single pull request comment with a clear pass/fail heading, emoji status indicators, the standards result table, and a link back to the workflow run. A hidden marker lets later runs find and update the same comment. This keeps reviewer visibility high while avoiding repeated comment spam.

## Adding More Rules

Create another sorted shell script in the relevant bundled category directory, such as `.github/actions/repo-standards/policies/documentation`, or add caller-specific scripts under `.github/repo-standards/checks` in a consuming repository.

The runner sources each check in the same shell, so checks can use `pass`, `fail`, and the shared `standards_*` helper functions for common file, byte-count, and pattern assertions.

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

check_name="License is present"
license_path="LICENSE"

standards_require_non_empty_file "$check_name" "$license_path" "Add a root-level LICENSE file." || return 0
pass "$check_name" "$license_path exists and contains content."
```

Use small focused checks so failures are easy to understand and safe to require across many repositories.

Consuming repositories can add repository-specific checks by passing `check-directory` to the reusable workflow. For compatibility with the previous workflow default, `.github/repo-standards/checks` is also included automatically when it exists in the caller repository. The bundled categorized policies run first, and caller-specific checks are reported under `Custom policies`.
