# Repository Standards Workflow

## Purpose

Repository standards make basic project expectations visible, automated, and consistent. The rules are deliberately simple and high-signal: every repository must have root documentation, ownership metadata, security reporting guidance, contributor workflow guidance, AI agent guardrails, ignore rules for local/generated artifacts, dependency update automation, security/supply-chain analysis, and ownership/catalog metadata.

The bundled implementation is organized into policy categories:

| Category | Directory | Purpose |
| --- | --- | --- |
| Documentation policies | `.github/actions/repo-standards/policies/documentation` | Repository entry points and contributor guidance. |
| Repository identity policies | `.github/actions/repo-standards/policies/repository-identity` | Review routing, ownership, and catalog metadata. |
| Developer hygiene policies | `.github/actions/repo-standards/policies/developer-hygiene` | AI agent guardrails and local/generated artifact hygiene. |
| Security policies | `.github/actions/repo-standards/policies/security` | Vulnerability reporting and required security analysis automation. |
| Supply-chain policies | `.github/actions/repo-standards/policies/supply-chain` | Dependency update automation and npm install reproducibility. |

The reusable workflow still emits one stable required-check context, while the Markdown summary includes the policy category for each result. That balance keeps organization-level branch protection easy to manage without hiding which guardrail failed.

Every category shares the same `.github/actions/repo-standards` composite action and shell validator. Adding a policy means adding a small sourced shell script to a category folder, not creating another workflow, checkout sequence, summary formatter, or pull request comment implementation.

A README matters because it gives contributors and maintainers one reliable place to understand:

- what the repository contains,
- how to build or validate it,
- who the repository is for,
- where deeper documentation lives.

## Rule: Root README Required

The standards check requires:

- a file named `README.md`,
- located at the repository root,
- with at least one byte of content by default.

The path and minimum byte count are configurable in the bundled action config at `.github/actions/repo-standards/config.env`, or by passing a repository-specific config file through the reusable workflow. The policy-file checks also support path overrides for security, contributing, agent guidance, and ignore files. The config file supports simple `KEY=value` lines and comments; it is parsed as data instead of evaluated as shell.

## Rule: CODEOWNERS Required

The standards check requires:

- a file named `CODEOWNERS` at the repository root, or `.github/CODEOWNERS`,
- at least one non-comment owner entry,
- at least one owner listed for that entry.

Ownership metadata helps reviewers, maintainers, and automation understand who is responsible for changes across the repository.


## Rule: Security Policy Required

The standards check requires:

- a file named `SECURITY.md`,
- located at the repository root by default,
- with non-empty content that tells contributors how to report suspected vulnerabilities privately.

Security policy documentation is a guardrail for incident response. It prevents contributors from disclosing sensitive findings in public issues and gives maintainers a single place to document secure development expectations such as least-privilege automation, secret rotation, dependency hygiene, and ownership of security-sensitive files.

## Rule: Contributing Guide Required

The standards check requires:

- a file named `CONTRIBUTING.md`,
- located at the repository root by default,
- with non-empty content that explains the expected contributor workflow.

Contributor documentation improves developer experience by making setup, validation, pull request expectations, documentation updates, screenshots, and review handoffs explicit. A healthy repository should not rely on tribal knowledge for routine contributions.

## Rule: Agent Guidance Required

The standards check requires one non-empty AI agent guidance file, accepted in this order by default:

- `agent.md`,
- `AGENTS.md`,
- `.github/AGENTS.md`.

Agent guidance documents how automated coding agents should work in the repository. It should describe preserved design intent, validation commands, documentation expectations, generated-artifact rules, and repository-specific constraints. This keeps future agent contributions aligned with maintainers instead of leaving agents to infer policy from existing files alone.

## Rule: Root Git Ignore Required

The standards check requires:

- a file named `.gitignore`,
- located at the repository root by default,
- with non-empty content.

Ignore rules are a lightweight control for repository hygiene. They reduce accidental commits of local caches, editor state, build output, test artifacts, agent scratch files, and other generated files that should not become long-lived source artifacts.

## Rule: Dependency Update Automation Required

The standards check requires a non-empty `.github/dependabot.yml` by default with at least one `package-ecosystem` entry. For this repository the baseline covers GitHub Actions updates weekly, which keeps reusable workflow dependencies visible to maintainers.

## Rule: Security and Supply Chain Analysis Required

The standards check requires a non-empty security analysis workflow at `.github/workflows/security-analysis.yml` by default. The workflow should declare at least one recognizable analyzer such as CodeQL, OpenSSF Scorecard, dependency review, Trivy, SLSA provenance, or SARIF upload. This repository includes CodeQL analysis for the portal JavaScript and OpenSSF Scorecard results uploaded as SARIF.

Recommended GitHub platform controls to pair with the workflow include:

- secret scanning and push protection,
- Dependabot alerts and security updates,
- branch protection or rulesets that require standards and security checks,
- least-privilege workflow permissions,
- reviewed third-party actions and pinned action upgrade ownership.

## Rule: Ownership Metadata Required

The standards check requires either `ownership.yaml` or `catalog-info.yaml` by default. `CODEOWNERS` routes review requests, while ownership metadata records human and platform context such as the owning team, security contact, escalation channel, service tier, system, lifecycle, and catalog annotations.

This repository includes both:

- `ownership.yaml` for repository governance and team escalation metadata,
- `catalog-info.yaml` as a Backstage-compatible `Component` descriptor for software catalog ingestion.

## Rule: npm Supply-Chain Policy Required When npm Is Detected

The standards check detects npm projects by finding `package.json` files outside `.git` and `node_modules`. When any npm project is present, every detected project must pass `tools/validate-npm-policy.mjs`.

The npm policy requires:

- a committed `package-lock.json` with a modern lockfile version and a root package entry;
- a project `.npmrc` with `package-lock=true`, `save-exact=true`, `ignore-scripts=true`, `audit=true`, and `fund=false`;
- a package script named `install:locked` that runs `npm ci --ignore-scripts`;
- exact registry dependency versions in `dependencies`, `devDependencies`, and `optionalDependencies`, while allowing local and alias specifications such as `file:`, `workspace:`, `link:`, and `npm:`;
- lock-file dependency declarations that match `package.json`;
- an `engines.npm` declaration so contributors and automation use a known npm baseline;
- a repository policy at `.github/npm-supply-chain-policy.json` that requires a dependency release cool-down, lock-file usage, exact registry versions, disabled install scripts by default, npm audit, and disabled funding prompts.

This rule keeps npm installs reproducible: required workflows must use `npm ci --ignore-scripts`, which installs only the package set and versions represented in the committed lock file and fails instead of rewriting dependency resolution.


## Secure npm Package Manager Skeleton

The repository includes a minimal npm skeleton under `examples/npm-secure-skeleton` and a local package under `examples/safe-greeter`. The sample application imports `@example/safe-greeter` from the locked dependency tree and can be run with `npm start` after a locked install.

The convention for npm projects is:

- commit `package.json`, `package-lock.json`, and the project `.npmrc`;
- install in automation with `npm ci --ignore-scripts` only;
- keep `package-lock=true` so npm writes and respects the lock file;
- keep `save-exact=true` so new registry dependencies are pinned exactly;
- keep `ignore-scripts=true` so dependency lifecycle scripts do not run by default;
- keep `audit=true` so npm audit metadata remains available;
- keep `fund=false` so automated installs do not emit funding prompts;
- require a cool-down period before adopting newly published registry versions. This repository records that policy as `minimumReleaseAgeDays` in `.github/npm-supply-chain-policy.json`;
- validate the convention with `node tools/validate-npm-policy.mjs examples/npm-secure-skeleton`.

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

Use small focused checks so failures are easy to understand and safe to require across many repositories.

Consuming repositories can add repository-specific checks by passing `check-directory` to the reusable workflow. For compatibility with the previous workflow default, `.github/repo-standards/checks` is also included automatically when it exists in the caller repository. The bundled categorized policies run first, and caller-specific checks are reported under `Custom policies`.
