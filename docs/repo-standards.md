# Repository Standards Workflow

## Purpose

Repository standards make basic project expectations visible, automated, and consistent. The rules are deliberately simple and high-signal: every repository must have root documentation, ownership metadata, security reporting guidance, contributor workflow guidance, AI agent guardrails, ignore rules for local/generated artifacts, dependency update automation, security/supply-chain analysis, and ownership/catalog metadata.

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

## Developer Experience

The workflow is designed to be quick and predictable:

- no dependency installation,
- no package registry calls,
- one shell runner for standards checks,
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

## Pull Request Comment Behavior

The workflow uses the shared comment action at `.github/actions/repo-standards-comment` to post a single pull request comment with a clear pass/fail heading, emoji status indicators, the standards result table, and a link back to the workflow run. A hidden marker lets later runs find and update the same comment. This keeps reviewer visibility high while avoiding repeated comment spam.

## Adding More Rules

Create another sorted shell script in `.github/actions/repo-standards/checks`.

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

Consuming repositories can add repository-specific checks by passing `check-directory` to the reusable workflow. For compatibility with the previous workflow default, `.github/repo-standards/checks` is also included automatically when it exists in the caller repository. The bundled checks still run first.
