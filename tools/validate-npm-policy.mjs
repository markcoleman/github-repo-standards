#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const projectDir = path.resolve(root, process.argv[2] ?? 'examples/npm-secure-skeleton');
const policyPath = path.resolve(root, '.github/npm-supply-chain-policy.json');
const failures = [];

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    failures.push(`Unable to read valid JSON from ${path.relative(root, filePath)}: ${error.message}`);
    return {};
  }
}

function requireFile(filePath) {
  if (!fs.existsSync(filePath)) {
    failures.push(`Missing required file: ${path.relative(root, filePath)}`);
    return false;
  }
  return true;
}

function parseNpmrc(filePath) {
  const settings = new Map();
  if (!requireFile(filePath)) return settings;

  const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#') || trimmed.startsWith(';')) continue;
    const separatorIndex = trimmed.indexOf('=');
    if (separatorIndex === -1) continue;
    settings.set(trimmed.slice(0, separatorIndex).trim(), trimmed.slice(separatorIndex + 1).trim());
  }
  return settings;
}

function assertEqual(actual, expected, message) {
  if (actual !== expected) failures.push(`${message}: expected ${expected}, found ${actual ?? '<unset>'}`);
}

function assertExactDependencyVersions(dependencies, groupName) {
  for (const [name, spec] of Object.entries(dependencies ?? {})) {
    const isLocalOrAlias = /^(file:|workspace:|link:|npm:)/.test(spec);
    const isExactRegistryVersion = /^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(spec);
    if (!isLocalOrAlias && !isExactRegistryVersion) {
      failures.push(`${groupName}.${name} must use an exact version or an approved local/alias spec, found ${spec}`);
    }
  }
}

const packagePath = path.join(projectDir, 'package.json');
const lockPath = path.join(projectDir, 'package-lock.json');
const npmrcPath = path.join(projectDir, '.npmrc');

requireFile(policyPath);
requireFile(packagePath);
requireFile(lockPath);

const policy = readJson(policyPath);
const pkg = readJson(packagePath);
const lock = readJson(lockPath);
const npmrc = parseNpmrc(npmrcPath);

if (policy.requireLockfile !== true) failures.push('Policy must require a lockfile.');
if (!Number.isInteger(policy.minimumReleaseAgeDays) || policy.minimumReleaseAgeDays < 7) {
  failures.push('Policy must set minimumReleaseAgeDays to an integer of at least 7.');
}
if (policy.installCommand !== 'npm ci --ignore-scripts') {
  failures.push('Policy installCommand must be npm ci --ignore-scripts.');
}
if (policy.requireExactRegistryVersions !== true) failures.push('Policy must require exact registry versions.');
if (policy.allowInstallScriptsByDefault !== false) failures.push('Policy must disable install scripts by default.');

assertEqual(npmrc.get('package-lock'), 'true', '.npmrc package-lock setting');
assertEqual(npmrc.get('save-exact'), 'true', '.npmrc save-exact setting');
assertEqual(npmrc.get('ignore-scripts'), 'true', '.npmrc ignore-scripts setting');

if (pkg.scripts?.['install:locked'] !== 'npm ci --ignore-scripts') {
  failures.push('package.json must expose scripts.install:locked as npm ci --ignore-scripts.');
}

assertExactDependencyVersions(pkg.dependencies, 'dependencies');
assertExactDependencyVersions(pkg.devDependencies, 'devDependencies');
assertExactDependencyVersions(pkg.optionalDependencies, 'optionalDependencies');

if (lock.lockfileVersion === undefined) failures.push('package-lock.json must include lockfileVersion.');
const rootPackage = lock.packages?.[''];
if (!rootPackage) failures.push('package-lock.json must include the root package entry.');
if (rootPackage && JSON.stringify(rootPackage.dependencies ?? {}) !== JSON.stringify(pkg.dependencies ?? {})) {
  failures.push('package-lock.json root dependencies must match package.json dependencies.');
}

if (failures.length > 0) {
  console.error('npm supply-chain policy validation failed:');
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(`npm supply-chain policy validation passed for ${path.relative(root, projectDir)}.`);
