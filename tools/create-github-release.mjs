#!/usr/bin/env node
import { appendFile, readFile } from "node:fs/promises";

const validBumps = new Set(["major", "minor", "patch"]);
const defaultApiVersion = "2022-11-28";

function usage() {
  console.log(`Usage: node tools/create-github-release.mjs

Creates a GitHub release from a completed pull request or a manual workflow run.

Important environment variables:
  GITHUB_TOKEN                 Token with contents:write.
  GITHUB_EVENT_PATH            Path to the GitHub Actions event payload.
  RELEASE_REPOSITORY           owner/repo. Defaults to GITHUB_REPOSITORY.
  RELEASE_TAG                  Optional explicit release tag.
  RELEASE_BUMP                 Optional explicit semver bump: major, minor, patch.
  RELEASE_DEFAULT_BUMP         Optional fallback bump for unlabeled merged PRs.
  RELEASE_TAG_PREFIX           Tag prefix for generated versions. Default: v.
  RELEASE_CONFIG_FILE          GitHub release notes config path. Default: .github/release.yml.
  RELEASE_DRAFT                Create a draft release. Default: true.
  RELEASE_PUBLISH              Publish immediately when true.
`);
}

function env(name, fallback = "") {
  const value = process.env[name];
  return value === undefined || value === null ? fallback : value;
}

function normalizeOptional(value) {
  const trimmed = String(value ?? "").trim();
  return trimmed === "" || trimmed === "null" || trimmed === "undefined" ? "" : trimmed;
}

function parseBool(value, fallback = false) {
  const normalized = normalizeOptional(value).toLowerCase();
  if (!normalized) {
    return fallback;
  }
  if (["1", "true", "yes", "y", "on"].includes(normalized)) {
    return true;
  }
  if (["0", "false", "no", "n", "off"].includes(normalized)) {
    return false;
  }
  return fallback;
}

function normalizeBump(value) {
  const normalized = normalizeOptional(value).toLowerCase();
  return validBumps.has(normalized) ? normalized : "";
}

function parseSemverTag(tagName, tagPrefix = "v") {
  let candidate = normalizeOptional(tagName);
  const prefix = normalizeOptional(tagPrefix);
  if (prefix && candidate.startsWith(prefix)) {
    candidate = candidate.slice(prefix.length);
  }

  const match = candidate.match(/^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/);
  if (!match) {
    return null;
  }

  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
  };
}

function bumpVersion(previousVersion, bump) {
  if (!previousVersion) {
    if (bump === "major") {
      return { major: 1, minor: 0, patch: 0 };
    }
    if (bump === "minor") {
      return { major: 0, minor: 1, patch: 0 };
    }
    return { major: 0, minor: 0, patch: 1 };
  }

  if (bump === "major") {
    return { major: previousVersion.major + 1, minor: 0, patch: 0 };
  }
  if (bump === "minor") {
    return { major: previousVersion.major, minor: previousVersion.minor + 1, patch: 0 };
  }
  return { major: previousVersion.major, minor: previousVersion.minor, patch: previousVersion.patch + 1 };
}

function formatTag(version, tagPrefix = "v") {
  return `${tagPrefix}${version.major}.${version.minor}.${version.patch}`;
}

function labelsFromPullRequest(pullRequest) {
  if (!pullRequest || !Array.isArray(pullRequest.labels)) {
    return [];
  }
  return pullRequest.labels.map((label) => String(label?.name ?? label)).filter(Boolean);
}

function resolveReleaseDecision({ explicitTag, explicitBump, defaultBump, labels, labelPrefix }) {
  const normalizedLabels = labels.map((label) => label.toLowerCase());
  const prefix = labelPrefix.toLowerCase();

  if (normalizedLabels.includes(`${prefix}skip`) || normalizedLabels.includes("skip-release")) {
    return {
      shouldCreate: false,
      reason: `Release skipped because the pull request has a ${labelPrefix}skip or skip-release label.`,
    };
  }

  const tag = normalizeOptional(explicitTag);
  if (tag) {
    return { shouldCreate: true, explicitTag: tag, bump: "", source: "explicit tag" };
  }

  const requestedBump = normalizeBump(explicitBump);
  if (requestedBump) {
    return { shouldCreate: true, bump: requestedBump, source: "workflow input" };
  }

  const labelBump = normalizedLabels
    .filter((label) => label.startsWith(prefix))
    .map((label) => normalizeBump(label.slice(prefix.length)))
    .find(Boolean);

  if (labelBump) {
    return { shouldCreate: true, bump: labelBump, source: "pull request label" };
  }

  const fallbackBump = normalizeBump(defaultBump);
  if (fallbackBump) {
    return { shouldCreate: true, bump: fallbackBump, source: "default bump" };
  }

  return {
    shouldCreate: false,
    reason: `No release was created. Add a ${labelPrefix}major, ${labelPrefix}minor, or ${labelPrefix}patch label before merge, run the workflow manually, or set RELEASE_DEFAULT_BUMP.`,
  };
}

async function readEventPayload() {
  const eventPath = normalizeOptional(env("GITHUB_EVENT_PATH"));
  if (!eventPath) {
    return {};
  }
  return JSON.parse(await readFile(eventPath, "utf8"));
}

function splitRepository(repository) {
  const value = normalizeOptional(repository);
  const [owner, repo] = value.split("/");
  if (!owner || !repo) {
    throw new Error(`Expected RELEASE_REPOSITORY or GITHUB_REPOSITORY to be owner/repo; received "${value}".`);
  }
  return { owner, repo, fullName: `${owner}/${repo}` };
}

function createGitHubClient({ apiUrl, token, owner, repo }) {
  const baseUrl = `${apiUrl.replace(/\/$/, "")}/repos/${owner}/${repo}`;
  const headers = {
    Accept: "application/vnd.github+json",
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
    "X-GitHub-Api-Version": env("GITHUB_API_VERSION", defaultApiVersion),
  };

  return {
    async request(method, path, body) {
      const response = await fetch(`${baseUrl}${path}`, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
      });
      const text = await response.text();
      let data = null;
      if (text) {
        try {
          data = JSON.parse(text);
        } catch {
          data = { message: text };
        }
      }

      if (!response.ok) {
        const error = new Error(`${method} ${path} failed with ${response.status}: ${data?.message ?? text}`);
        error.status = response.status;
        error.data = data;
        throw error;
      }

      return data;
    },
  };
}

async function listReleases(client) {
  const releases = [];
  for (let page = 1; page <= 10; page += 1) {
    const pageReleases = await client.request("GET", `/releases?per_page=100&page=${page}`);
    if (!Array.isArray(pageReleases) || pageReleases.length === 0) {
      break;
    }
    releases.push(...pageReleases);
    if (pageReleases.length < 100) {
      break;
    }
  }
  return releases;
}

async function getReleaseByTag(client, tagName) {
  try {
    return await client.request("GET", `/releases/tags/${encodeURIComponent(tagName)}`);
  } catch (error) {
    if (error.status === 404) {
      return null;
    }
    throw error;
  }
}

function findPreviousRelease(releases, { includePrereleases }) {
  return releases.find((release) => !release.draft && (includePrereleases || !release.prerelease)) ?? null;
}

function markdownTableCell(value) {
  return String(value ?? "")
    .replace(/\\/g, "\\\\")
    .replace(/\r?\n/g, " ")
    .replace(/\|/g, "\\|");
}

function shortSha(value) {
  const sha = normalizeOptional(value);
  return sha ? sha.slice(0, 12) : "";
}

function releaseMetadataRows({ pullRequest, fullName, tagName, previousTagName, targetCommitish, bump, decisionSource, draft, prerelease }) {
  const rows = [];
  const compareUrl = previousTagName
    ? `https://github.com/${fullName}/compare/${encodeURIComponent(previousTagName)}...${encodeURIComponent(tagName)}`
    : "";

  rows.push(["Tag", `\`${tagName}\``]);
  rows.push(["Previous release", previousTagName ? `\`${previousTagName}\`` : "First release"]);
  if (compareUrl) {
    rows.push(["Compare", `[${previousTagName}...${tagName}](${compareUrl})`]);
  }
  if (pullRequest) {
    rows.push(["Source PR", `[#${pullRequest.number}](${pullRequest.html_url})`]);
    rows.push(["Merged by", pullRequest.merged_by?.login ? `@${pullRequest.merged_by.login}` : "GitHub"]);
  } else {
    rows.push(["Source", "Manual workflow run"]);
  }
  rows.push(["Target commit", shortSha(targetCommitish) ? `\`${shortSha(targetCommitish)}\`` : "Workflow ref"]);
  rows.push(["Version decision", bump ? `${bump} from ${decisionSource}` : decisionSource]);
  rows.push(["Release state", draft ? "Draft" : "Published"]);
  if (prerelease) {
    rows.push(["Prerelease", "Yes"]);
  }
  return rows;
}

function buildReleaseBody(context) {
  const metadataRows = releaseMetadataRows(context)
    .map(([field, value]) => `| ${markdownTableCell(field)} | ${markdownTableCell(value)} |`)
    .join("\n");

  const reviewChecklist = context.draft
    ? `
## Maintainer Review

- Confirm the generated categories match the merged changes.
- Add migration, rollout, or rollback notes when the release needs human context.
- Publish the draft once deployment or distribution timing is approved.
`
    : "";

  return `## Release Metadata

| Field | Value |
| --- | --- |
${metadataRows}
${reviewChecklist}
---

${context.generatedBody.trim()}
`;
}

async function appendOutput(key, value) {
  const outputPath = normalizeOptional(env("GITHUB_OUTPUT"));
  if (!outputPath) {
    return;
  }
  await appendFile(outputPath, `${key}=${String(value ?? "")}\n`);
}

async function appendSummary(markdown) {
  const summaryPath = normalizeOptional(env("GITHUB_STEP_SUMMARY"));
  if (!summaryPath) {
    return;
  }
  await appendFile(summaryPath, `${markdown.trim()}\n`);
}

function buildRunSummary({ created, skipped, release, tagName, previousTagName, reason }) {
  if (skipped) {
    return `## Release on PR Complete

${reason}
`;
  }

  return `## Release on PR Complete

| Field | Value |
| --- | --- |
| Result | ${created ? "Created release" : "Release already existed"} |
| Tag | \`${tagName}\` |
| Previous release | ${previousTagName ? `\`${previousTagName}\`` : "First release"} |
| URL | ${release?.html_url ? `[Open release](${release.html_url})` : "Not available"} |
`;
}

function buildPullRequestComment({ created, release, tagName, previousTagName, draft }) {
  const result = created ? "created" : "already exists";
  const state = draft ? "draft " : "";
  return `## Release ${result}

The ${state}release for \`${tagName}\` ${result}.

| Field | Value |
| --- | --- |
| Release | ${release?.html_url ? `[${tagName}](${release.html_url})` : `\`${tagName}\``} |
| Previous release | ${previousTagName ? `\`${previousTagName}\`` : "First release"} |
| Notes | Generated from GitHub release-note categories |
`;
}

async function maybeCommentOnPullRequest(client, pullRequest, commentBody) {
  if (!pullRequest?.number || !parseBool(env("RELEASE_COMMENT_ON_PR", "true"), true)) {
    return;
  }
  await client.request("POST", `/issues/${pullRequest.number}/comments`, { body: commentBody });
}

async function main() {
  if (process.argv.includes("--help") || process.argv.includes("-h")) {
    usage();
    return;
  }

  const event = await readEventPayload();
  const pullRequest = event.pull_request ?? null;
  const labels = labelsFromPullRequest(pullRequest);
  const labelPrefix = env("RELEASE_LABEL_PREFIX", "release:");
  const releaseDecision = resolveReleaseDecision({
    explicitTag: env("RELEASE_TAG"),
    explicitBump: env("RELEASE_BUMP"),
    defaultBump: env("RELEASE_DEFAULT_BUMP"),
    labels,
    labelPrefix,
  });

  if (!releaseDecision.shouldCreate) {
    await appendOutput("created", "false");
    await appendSummary(buildRunSummary({ skipped: true, reason: releaseDecision.reason }));
    console.log(releaseDecision.reason);
    return;
  }

  const token = normalizeOptional(env("GITHUB_TOKEN"));
  if (!token) {
    throw new Error("GITHUB_TOKEN is required to create a GitHub release.");
  }

  const repository = splitRepository(env("RELEASE_REPOSITORY", env("GITHUB_REPOSITORY", event.repository?.full_name ?? "")));
  const client = createGitHubClient({
    apiUrl: env("RELEASE_API_URL", env("GITHUB_API_URL", "https://api.github.com")),
    token,
    owner: repository.owner,
    repo: repository.repo,
  });

  const includePrereleases = parseBool(env("RELEASE_INCLUDE_PRERELEASES"), false);
  const releases = await listReleases(client);
  const previousRelease = findPreviousRelease(releases, { includePrereleases });
  const previousTagName = normalizeOptional(env("RELEASE_PREVIOUS_TAG")) || previousRelease?.tag_name || "";
  const tagPrefix = env("RELEASE_TAG_PREFIX", "v");

  let tagName = releaseDecision.explicitTag;
  if (!tagName) {
    const previousVersion = previousTagName ? parseSemverTag(previousTagName, tagPrefix) : null;
    if (previousTagName && !previousVersion) {
      throw new Error(
        `Latest release tag "${previousTagName}" is not a semver tag with prefix "${tagPrefix}". Set RELEASE_TAG or RELEASE_PREVIOUS_TAG explicitly.`,
      );
    }
    tagName = formatTag(bumpVersion(previousVersion, releaseDecision.bump), tagPrefix);
  }

  if (previousTagName === tagName) {
    throw new Error(`Refusing to create release ${tagName}; it matches the previous release tag.`);
  }

  const targetCommitish =
    normalizeOptional(env("RELEASE_TARGET_COMMITISH")) ||
    normalizeOptional(pullRequest?.merge_commit_sha) ||
    normalizeOptional(env("GITHUB_SHA")) ||
    normalizeOptional(event.after);

  const draft = parseBool(env("RELEASE_PUBLISH"), false) ? false : parseBool(env("RELEASE_DRAFT"), true);
  const prerelease = parseBool(env("RELEASE_PRERELEASE"), false);
  const releaseConfigFile = env("RELEASE_CONFIG_FILE", ".github/release.yml");

  const existingRelease = await getReleaseByTag(client, tagName);
  if (existingRelease) {
    await appendOutput("created", "false");
    await appendOutput("release_url", existingRelease.html_url ?? "");
    await appendOutput("release_tag", tagName);
    await appendOutput("previous_tag", previousTagName);
    await appendSummary(buildRunSummary({ created: false, release: existingRelease, tagName, previousTagName }));
    await maybeCommentOnPullRequest(
      client,
      pullRequest,
      buildPullRequestComment({ created: false, release: existingRelease, tagName, previousTagName, draft: existingRelease.draft }),
    );
    console.log(`Release ${tagName} already exists: ${existingRelease.html_url}`);
    return;
  }

  const generatePayload = {
    tag_name: tagName,
    target_commitish: targetCommitish,
    configuration_file_path: releaseConfigFile,
  };
  if (previousTagName) {
    generatePayload.previous_tag_name = previousTagName;
  }

  const generatedNotes = await client.request("POST", "/releases/generate-notes", generatePayload);
  const body = buildReleaseBody({
    pullRequest,
    fullName: repository.fullName,
    tagName,
    previousTagName,
    targetCommitish,
    bump: releaseDecision.bump,
    decisionSource: releaseDecision.source,
    draft,
    prerelease,
    generatedBody: generatedNotes.body ?? "",
  });

  const release = await client.request("POST", "/releases", {
    tag_name: tagName,
    target_commitish: targetCommitish,
    name: generatedNotes.name || `Release ${tagName}`,
    body,
    draft,
    prerelease,
  });

  await appendOutput("created", "true");
  await appendOutput("release_url", release.html_url ?? "");
  await appendOutput("release_tag", tagName);
  await appendOutput("previous_tag", previousTagName);
  await appendSummary(buildRunSummary({ created: true, release, tagName, previousTagName }));
  await maybeCommentOnPullRequest(
    client,
    pullRequest,
    buildPullRequestComment({ created: true, release, tagName, previousTagName, draft }),
  );

  console.log(`Created ${draft ? "draft " : ""}release ${tagName}: ${release.html_url}`);
}

main().catch(async (error) => {
  await appendSummary(`## Release on PR Complete

Release creation failed: ${error.message}
`);
  console.error(error);
  process.exit(1);
});
