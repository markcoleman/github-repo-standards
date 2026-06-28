# Pull Request Release Process

## Purpose

The release process turns an intentionally marked, completed pull request into a GitHub release with a low-friction maintainer review step. It uses GitHub's generated release notes so the release body contains the pull requests, contributors, and category grouping since the previous release, then wraps those notes in a small metadata section that is easy to scan from the GitHub Releases page or a developer portal.

The default is safe for teams that want automation without surprise publication: merged pull requests create draft releases only when they opt in with a release label. Maintainers can review the generated notes, add rollout context, and publish when timing is right.

## Default Flow

1. Add one release intent label to the pull request before merge:
   - `release:patch` for fixes and small compatible changes.
   - `release:minor` for compatible features or new capability.
   - `release:major` for breaking changes.
   - `release:skip` when a PR should not appear in release automation.
2. Merge the pull request into `main`.
3. The release workflow reads the latest published GitHub release, excluding drafts by default.
4. The workflow calculates the next semver tag, calls GitHub's generated release notes endpoint with the previous tag and `.github/release.yml`, and creates a draft release.
5. The workflow comments the release link back onto the completed pull request.
6. A maintainer reviews the draft, adds migration or rollout notes when needed, and publishes.

Unlabeled pull requests are skipped by default. A consuming repository can set `default-bump: patch` if it wants every merged pull request to produce a draft patch release.

## Reusable Workflow Adoption

Add this caller workflow to repositories that should use the shared release process:

```yaml
name: Release on PR Complete

on:
  pull_request:
    types:
      - closed
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    uses: OWNER/github-repo-standards/.github/workflows/release-on-pr-complete.yml@main
```

Replace `OWNER` with the account or organization that owns this standards repository.

To create a draft patch release for every merged pull request, add:

```yaml
jobs:
  release:
    uses: OWNER/github-repo-standards/.github/workflows/release-on-pr-complete.yml@main
    with:
      default-bump: patch
```

## Release Note Categories

The shared `.github/release.yml` groups generated notes into:

| Category | Labels |
| --- | --- |
| Breaking Changes | `release:major`, `breaking-change`, `breaking` |
| Features | `release:minor`, `enhancement`, `feature` |
| Fixes | `release:patch`, `bug`, `fix` |
| Security | `security`, `vulnerability` |
| Dependencies | `dependencies`, `github-actions`, `npm` |
| Documentation | `documentation`, `docs` |
| Developer Experience | `developer-experience`, `dx`, `ci`, `tooling` |
| Other Changes | Any PR not matched by a previous category |

Use `skip-changelog`, `ignore-for-release`, or `release:skip` for changes that should be excluded from release notes.

## Workflow Inputs

The reusable workflow supports:

| Input | Default | Description |
| --- | --- | --- |
| `default-bump` | `''` | Optional semver bump for merged PRs without a release intent label. Leave empty to skip unlabeled PRs. |
| `tag-prefix` | `v` | Prefix for generated tags such as `v1.2.3`. |
| `release-config-file` | `.github/release.yml` | Generated release notes category configuration. |
| `draft` | `true` | Creates draft releases by default. Set to `false` only when the team is ready for automatic publication. |
| `prerelease` | `false` | Marks created releases as prereleases. |
| `comment-on-pr` | `true` | Posts the release link back to the completed pull request. |

Manual `workflow_dispatch` runs can provide an explicit tag, choose a semver bump, mark the release as a prerelease, or publish immediately.

## Release Body Format

Each generated release starts with a compact metadata table:

- tag and previous release,
- compare link,
- source pull request or manual run,
- target commit,
- version decision,
- draft or published state.

The generated release notes follow that metadata. Draft releases also include a maintainer review checklist so the release page itself tells reviewers what to confirm before publication.

## Operational Notes

- The workflow uses `contents: write` to create releases and tags, plus `issues: write` and `pull-requests: write` to comment on the completed pull request.
- Reruns are idempotent for the selected tag: if a release already exists, the workflow links to it instead of creating a duplicate.
- The previous release defaults to the latest published release. Set `RELEASE_PREVIOUS_TAG` in a custom wrapper only when a repository needs to override that range.
- If the previous release tag is not semver-compatible and no explicit tag is supplied, the workflow fails with remediation text instead of guessing.
- Keep PR titles release-note friendly. The generated notes use merged PR titles as the primary change lines.
