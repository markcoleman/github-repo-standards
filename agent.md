# Agent Guide

This repository owns a reusable GitHub Actions workflow for repository standards.

## What To Preserve

- Keep the standards runner dependency-free and fast.
- Keep checks small, deterministic, and easy to explain.
- Prefer adding new bundled standards as separate files in `.github/actions/repo-standards/checks`.
- Keep pull request output readable for reviewers.

## Validation

Run this before finishing changes:

```bash
.github/actions/repo-standards/validate-repo-standards.sh
```

When changing workflow behavior, review `.github/workflows/repo-standards.yml` and update `docs/repo-standards.md` if adoption guidance changes.

## Design Intent

The root `README.md` and `CODEOWNERS` rules are the first standards because they are broadly useful, low cost, and easy to enforce. Future checks should follow the same pattern: high signal, low surprise, and clear remediation.
