// Keeps website/src/data/versions.json: the release in which each test, command and command parameter first
// appeared. The site compares it with website/version-config.js to mark what is only in the preview.
//
// Usage (from website/):
//   node scripts/update-versions.mjs <version>          # record what the current source contains as <version>
//   node scripts/update-versions.mjs --seed-2x <git-ref> # one-off: record what Maester 2.3.0 shipped
//
// The publish-module workflow runs the first form for every stable release. Entries are only ever added: an
// item keeps the version it first appeared in.

import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const websiteRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = join(websiteRoot, "..");
const versionsPath = join(websiteRoot, "src", "data", "versions.json");
const catalogPath = join(websiteRoot, "src", "data", "test-catalog.json");
const commandsRoot = join(websiteRoot, "docs", "commands");

function load() {
  if (!existsSync(versionsPath)) return { tests: {}, commands: {} };
  return JSON.parse(readFileSync(versionsPath, "utf8"));
}

function save(data) {
  const sorted = (obj) => Object.fromEntries(Object.keys(obj).sort((a, b) => a.localeCompare(b, undefined, { numeric: true })).map((k) => [k, obj[k]]));
  const commands = Object.fromEntries(
    Object.entries(sorted(data.commands)).map(([name, c]) => [name, { since: c.since, parameters: sorted(c.parameters ?? {}) }]),
  );
  writeFileSync(versionsPath, `${JSON.stringify({ tests: sorted(data.tests), commands }, null, 2)}\n`);
}

// The parameters a command page documents: its "### -Name" headings.
export function parametersOf(markdown) {
  return [...markdown.matchAll(/^###\s+-([A-Za-z][A-Za-z0-9]*)\s*$/gm)].map((m) => m[1]).filter((p) => p !== "ProgressAction");
}

function record(data, version, tests, commands) {
  for (const id of tests) data.tests[id] ??= version;
  for (const [name, params] of commands) {
    const entry = (data.commands[name] ??= { since: version, parameters: {} });
    for (const p of params) entry.parameters[p] ??= version;
  }
}

function seedFromGit(ref) {
  const git = (...args) => execFileSync("git", args, { cwd: repoRoot, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  const files = git("ls-tree", "-r", "--name-only", ref, "website/versioned_docs/version-2.3.0").split("\n");
  const tests = files
    .filter((f) => /\/tests\/[^/]+\/[^/]+\.md$/.test(f) && !/readme|overview/i.test(f))
    .map((f) => f.split("/").pop().replace(/\.md$/, ""));
  const commands = files
    .filter((f) => /\/commands\/[^/]+\.mdx$/.test(f))
    .map((f) => [f.split("/").pop().replace(/\.mdx$/, ""), parametersOf(git("show", `${ref}:${f}`))]);
  return { tests, commands };
}

function fromSource() {
  const catalog = JSON.parse(readFileSync(catalogPath, "utf8"));
  // The checks of the packs that ship with Maester count too, so their pages lose the preview notice once released.
  const tests = [...catalog.Tests.map((t) => t.Id), ...(catalog.Packs ?? []).flatMap((p) => (p.Tests ?? []).map((t) => t.Id))];
  const commands = readdirSync(commandsRoot)
    .filter((f) => f.endsWith(".mdx"))
    .map((f) => [f.replace(/\.mdx$/, ""), parametersOf(readFileSync(join(commandsRoot, f), "utf8"))]);
  return { tests, commands };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const data = load();
  const seedIndex = process.argv.indexOf("--seed-2x");
  if (seedIndex !== -1) {
    const { tests, commands } = seedFromGit(process.argv[seedIndex + 1] ?? "HEAD");
    record(data, "2.3.0", tests, commands);
    console.log(`Recorded ${tests.length} tests and ${commands.length} commands as 2.3.0.`);
  } else {
    const version = process.argv[2];
    if (!/^\d+\.\d+\.\d+$/.test(version ?? "")) {
      console.error("Usage: node scripts/update-versions.mjs <version>   (a stable version such as 3.0.0)");
      process.exit(1);
    }
    const { tests, commands } = fromSource();
    record(data, version, tests, commands);
    console.log(`Recorded ${tests.length} tests and ${commands.length} commands for ${version}.`);
  }
  save(data);
}
