// Converts the hand-maintained community tests registry (YAML, PR-friendly)
// into a JSON snapshot the community-tests page can import directly.
//
// Unlike contributors.mjs, this has no git-history dependency - it's a
// straight, cheap YAML -> JSON transform, so it just runs as a normal
// prebuild step rather than needing a dedicated scheduled workflow.

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { load as loadYamlDocument } from "js-yaml";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const websiteRoot = join(scriptDir, "..");
const registryPath = join(websiteRoot, "community-tests", "community-tests.yml");
const snapshotPath = join(websiteRoot, "src", "data", "community-tests.json");

const repositoryPattern = /^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\/[A-Za-z0-9._-]+$/;

function loadRegistry(path) {
  const raw = readFileSync(path, "utf8");
  return loadYamlDocument(raw) ?? {};
}

function validateEntry(key, entry) {
  const requiredFields = ["name", "repository", "description"];
  for (const field of requiredFields) {
    if (typeof entry?.[field] !== "string" || entry[field].trim() === "") {
      throw new Error(`community-tests.yml: entry '${key}' is missing required field '${field}'.`);
    }
  }
  if (!repositoryPattern.test(entry.repository)) {
    throw new Error(`community-tests.yml: entry '${key}' has an invalid 'repository' value '${entry.repository}' - expected 'owner/repo'.`);
  }
  if (
    entry.tags !== undefined &&
    (!Array.isArray(entry.tags) || entry.tags.some((tag) => typeof tag !== "string" || tag.trim() === ""))
  ) {
    throw new Error(`community-tests.yml: entry '${key}' has a 'tags' value that isn't a list of non-empty strings.`);
  }
  if (entry.author !== undefined && (typeof entry.author !== "string" || entry.author.trim() === "")) {
    throw new Error(`community-tests.yml: entry '${key}' has an 'author' value that isn't a non-empty string.`);
  }
  if (entry.authorUrl !== undefined && (typeof entry.authorUrl !== "string" || !entry.authorUrl.startsWith("https://"))) {
    throw new Error(`community-tests.yml: entry '${key}' has an 'authorUrl' value that isn't an https:// URL.`);
  }
}

const registry = loadRegistry(registryPath);

const entries = Object.entries(registry).map(([key, entry]) => {
  validateEntry(key, entry);
  return {
    key,
    name: entry.name,
    repository: entry.repository,
    description: entry.description,
    author: entry.author ?? null,
    authorUrl: entry.authorUrl ?? null,
    tags: entry.tags ?? [],
  };
});

entries.sort((a, b) => a.name.localeCompare(b.name));

writeFileSync(snapshotPath, `${JSON.stringify({ entries }, null, 2)}\n`);

console.log(`Generated ${entries.length} community test entr${entries.length === 1 ? "y" : "ies"}.`);
