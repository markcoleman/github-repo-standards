# Contributing Guide

## Purpose

A repository should be easy to validate before a contributor opens a pull request. This guide captures the minimum developer-experience expectations for repositories adopting the shared standards workflow.

## Before You Start

1. Read the repository README for purpose, setup, and validation commands.
2. Review CODEOWNERS to understand who should review changes.
3. Check open issues and pull requests to avoid duplicate work.
4. Confirm whether the repository has additional local standards under `.github/repo-standards`.

## Pull Request Expectations

Pull requests should include:

- a concise description of the change,
- linked issues or context when available,
- notes about risk, rollout, or migration steps,
- screenshots for visible application changes,
- validation commands and their results.

Keep pull requests focused. Prefer several small, reviewable changes over one broad change that mixes unrelated concerns.

## Local Validation

Run the repository standards checks before asking for review:

```bash
.github/actions/repo-standards/validate-repo-standards.sh
```

If a consuming repository uses this standards package through the reusable workflow, run the equivalent local checks documented by that repository.

## Documentation Standards

When behavior changes, update the docs in the same pull request. At minimum, keep README setup instructions, security reporting details, agent guidance, and local validation commands current.

## Automation and Generated Artifacts

Generated files, model outputs, screenshots, lockfiles, and build artifacts should be committed only when they are intentional repository artifacts. Do not commit transient agent scratch files, temporary prompts, local caches, or credentials.
