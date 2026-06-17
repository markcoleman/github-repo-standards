# Repository Standards Workflow

## Purpose

Repository standards make basic project expectations visible, automated, and consistent. The initial rule is deliberately simple: every repository must have a root-level `README.md` with content.

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

The path and minimum byte count are configurable in `.github/repo-standards/config.env`. The config file supports simple `KEY=value` lines and comments; it is parsed as data instead of evaluated as shell.

## Developer Experience

The workflow is designed to be quick and predictable:

- no dependency installation,
- no network calls beyond the GitHub API call used for pull request comments,
- one shell runner,
- short timeout,
- clear Markdown output locally and in GitHub Actions.

## Required Workflow Adoption

Repository administrators can add this workflow as a required workflow in GitHub branch protection or rulesets after referencing it from each repository. The workflow supports `workflow_call`, which makes the standards implementation reusable while still allowing each consuming repository to decide when it runs.

Example:

```yaml
jobs:
  repo-standards:
    uses: OWNER/github-repo-standards/.github/workflows/repo-standards.yml@main
```

The workflow keeps the execution path direct: check out the repository, then run `./scripts/validate-repo-standards.sh`. Repositories that call this workflow through `workflow_call` should include the standards script and check directory paths referenced by the workflow inputs.

## Pull Request Comment Behavior

The workflow posts a single pull request comment containing the standards result table. A hidden marker lets later runs find and update the same comment. This keeps reviewer visibility high while avoiding repeated comment spam.

## Adding More Rules

Create another sorted shell script in `.github/repo-standards/checks`.

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ -f "CODEOWNERS" || -f ".github/CODEOWNERS" ]]; then
  pass "CODEOWNERS is present" "Ownership metadata exists."
else
  fail "CODEOWNERS is present" "Add CODEOWNERS or .github/CODEOWNERS."
fi
```

Use small focused checks so failures are easy to understand and safe to require across many repositories.

Consuming repositories can add repository-specific checks by passing `check-directory` to the reusable workflow. The bundled checks still run first.
