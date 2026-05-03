import fs from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import process from 'node:process';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(SCRIPT_DIR, '..');
const PACKAGES_PATH = path.join(ROOT, 'config', 'foundry', 'packages.json');

function sortObjectKeys(value) {
  if (Array.isArray(value) || value === null || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.keys(value)
      .sort()
      .map((key) => [key, sortObjectKeys(value[key])]),
  );
}

function mergeObjects(base = {}, override = {}) {
  const out = { ...base };
  for (const [key, value] of Object.entries(override ?? {})) {
    if (Array.isArray(value)) out[key] = [...value];
    else if (value && typeof value === 'object' && !Array.isArray(value))
      out[key] = mergeObjects(base[key] ?? {}, value);
    else out[key] = value;
  }
  return out;
}

function tomlValue(value) {
  if (typeof value === 'string') return JSON.stringify(value);
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value)) return `[${value.map((item) => tomlValue(item)).join(', ')}]`;
  if (value && typeof value === 'object') {
    const entries = Object.keys(value)
      .sort()
      .map((key) => `${key} = ${tomlValue(value[key])}`);
    return `{ ${entries.join(', ')} }`;
  }
  throw new Error(`Unsupported TOML value: ${value}`);
}

function renderInlineTableEntry(key, value) {
  return `${key} = ${tomlValue(value)}`;
}

function renderSection(name, entries) {
  if (!entries.length) return '';
  return [`[${name}]`, ...entries].join('\n');
}

function renderPackageConfig(pkgName, pkgConfig, generatorMeta) {
  const profile = sortObjectKeys(pkgConfig.profile_default ?? {});
  const lint = pkgConfig.lint ? sortObjectKeys(pkgConfig.lint) : null;
  const selectedNetworks = pkgConfig.generator?.networks ?? [];

  const rpcEntries = [];
  const etherscanEntries = [];
  for (const network of selectedNetworks) {
    const meta = generatorMeta.network_catalog?.[network];
    if (!meta) throw new Error(`Unknown network "${network}" in package ${pkgName}`);
    rpcEntries.push(renderInlineTableEntry(network, '${' + meta.rpc_env + '}'));
    if (meta.explorer) {
      etherscanEntries.push(
        renderInlineTableEntry(
          network,
          sortObjectKeys({
            key: '${' + meta.explorer.key_env + '}',
            url: meta.explorer.url,
            chain: meta.explorer.chain,
          }),
        ),
      );
    }
  }

  const sections = [];
  const profileLines = Object.keys(profile)
    .sort()
    .map((key) => `${key} = ${tomlValue(profile[key])}`);
  sections.push(renderSection('profile.default', profileLines));
  if (lint && Object.keys(lint).length > 0)
    sections.push(
      renderSection(
        'lint',
        Object.keys(lint)
          .sort()
          .map((key) => `${key} = ${tomlValue(lint[key])}`),
      ),
    );
  if (rpcEntries.length > 0) sections.push(renderSection('rpc_endpoints', rpcEntries));
  if (etherscanEntries.length > 0) sections.push(renderSection('etherscan', etherscanEntries));
  return sections.filter(Boolean).join('\n\n') + '\n';
}

function assertSectionOrdering(rendered) {
  const profileIdx = rendered.indexOf('[profile.default]');
  if (profileIdx === -1) throw new Error('Missing [profile.default] section');

  const lintIdx = rendered.indexOf('[lint]');
  const rpcIdx = rendered.indexOf('[rpc_endpoints]');
  const etherscanIdx = rendered.indexOf('[etherscan]');
  for (const [name, idx] of [
    ['[lint]', lintIdx],
    ['[rpc_endpoints]', rpcIdx],
    ['[etherscan]', etherscanIdx],
  ]) {
    if (idx !== -1 && profileIdx > idx) throw new Error(`${name} appears before [profile.default]`);
  }

  const remappingsIdx = rendered.indexOf('remappings =');
  if (remappingsIdx !== -1) {
    const firstLaterSection = [lintIdx, rpcIdx, etherscanIdx]
      .filter((idx) => idx !== -1)
      .sort((a, b) => a - b)[0];
    if (firstLaterSection !== undefined && remappingsIdx > firstLaterSection) {
      throw new Error('remappings must stay within [profile.default] before later sections');
    }
  }
}

async function main() {
  const checkMode = process.argv.includes('--check');
  const raw = await fs.readFile(PACKAGES_PATH, 'utf8');
  const manifest = JSON.parse(raw);
  const outputs = new Map();

  for (const [pkgName, pkgSpec] of Object.entries(manifest.packages ?? {})) {
    const merged = {
      profile_default: mergeObjects(
        manifest.defaults?.profile_default ?? {},
        pkgSpec.profile_default ?? {},
      ),
      lint: pkgSpec.lint ? mergeObjects({}, pkgSpec.lint) : undefined,
      generator: pkgSpec.generator ?? {},
    };
    const rendered = renderPackageConfig(pkgName, merged, manifest.generator ?? {});
    assertSectionOrdering(rendered);
    outputs.set(path.join(ROOT, pkgName, 'foundry.toml'), rendered);
  }

  let drift = false;
  for (const [filePath, content] of outputs) {
    if (checkMode) {
      try {
        const existing = await fs.readFile(filePath, 'utf8');
        if (existing !== content) {
          drift = true;
          process.stderr.write(`drift: ${path.relative(ROOT, filePath)}\n`);
        }
      } catch {
        drift = true;
        process.stderr.write(`missing: ${path.relative(ROOT, filePath)}\n`);
      }
    } else {
      await fs.writeFile(filePath, content, 'utf8');
    }
  }

  if (checkMode && drift) process.exitCode = 1;
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exit(1);
});
