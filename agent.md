# Agent Guide

This repository owns a reusable GitHub Actions workflow for repository standards. Automated coding agents should preserve the workflow's simplicity while improving security, developer experience, and repository hygiene.

## What To Preserve

- Keep the standards runner dependency-free and fast.
- Keep checks small, deterministic, and easy to explain.
- Prefer adding new bundled standards as separate files in `.github/actions/repo-standards/checks`.
- Keep pull request output readable for reviewers.
- Do not commit transient scratch files, prompts, local caches, credentials, or one-off generated artifacts unless they are intentional repository assets.

## Validation

Run this before finishing changes:

```bash
.github/actions/repo-standards/validate-repo-standards.sh
```

When changing workflow behavior, review `.github/workflows/repo-standards.yml` and update `docs/repo-standards.md` if adoption guidance changes.

## Security Expectations

- Treat workflow permissions, third-party actions, and shell scripts as security-sensitive.
- Prefer least-privilege GitHub Actions permissions.
- Keep config parsing data-only; do not evaluate repository-provided config as shell.
- Never add secrets, tokens, or private vulnerability details to public examples.

## Developer Experience Expectations

- Keep remediation text actionable when a standards check fails.
- Update README and reference docs in the same change that updates standards behavior.
- Favor local commands that work without package installation or network access.

## Design Intent

The standards are broadly useful, low cost, and easy to enforce. Future checks should follow the same pattern: high signal, low surprise, and clear remediation.
