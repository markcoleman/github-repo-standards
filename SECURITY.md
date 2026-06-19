# Security Policy

## Purpose

Every repository should make security reporting and secure development expectations clear before an incident happens. This policy documents the minimum guardrails expected for repositories that adopt the shared repository standards workflow.

## Supported Scope

Security reports may include vulnerabilities in source code, automation, build scripts, infrastructure configuration, documentation that would cause unsafe operation, or repository settings that expose secrets or protected data.

## Reporting a Vulnerability

Do not open a public issue for a suspected vulnerability. Report security concerns through the private channel designated by the owning organization, such as GitHub private vulnerability reporting, an internal security intake queue, or the security contact listed in the repository README.

A useful report should include:

- the affected repository, branch, file, workflow, or release,
- a concise description of the impact,
- reproduction steps or proof-of-concept details when safe to share,
- whether credentials, tokens, customer data, or production systems may be affected,
- recommended mitigation if known.

## Maintainer Expectations

Repository maintainers should:

- acknowledge security reports promptly through the private intake channel,
- avoid requesting sensitive proof-of-concept material in public threads,
- rotate potentially exposed secrets before discussing details broadly,
- document remediation work in private until disclosure is approved,
- add or update automated checks when a class of issue can be prevented in future repositories.

## Secure Development Guardrails

Repositories should prefer:

- least-privilege tokens and GitHub Actions permissions,
- pinned or reviewed third-party automation,
- dependency update automation with human review,
- secret scanning and push protection,
- branch protection or rulesets for default branches,
- clear ownership for security-sensitive files through CODEOWNERS.
