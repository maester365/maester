// Compares the EIDSCA config upstream with the copy and classification in this repository, for the weekly
// eidsca-sync-check workflow. Writes the differences as JSON and the body of the sync issue as Markdown.
//
//   node scripts/check-eidsca-sync.mjs [--upstream <file>] [--json <file>] [--markdown <file>]
//
// Without --upstream the EIDSCA config is downloaded. Exits 0 whether or not there are differences.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { diffEidsca, renderIssueMarkdown, UPSTREAM_URL } from "../src/components/EidscaSync/diff.mjs";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..");

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function readJson(path) {
  // The EIDSCA config may start with a byte order mark.
  return JSON.parse(readFileSync(path, "utf8").replace(/^﻿/, ""));
}

async function main() {
  const upstreamPath = argument("--upstream");
  let upstream;
  if (upstreamPath) {
    upstream = readJson(upstreamPath);
  } else {
    const response = await fetch(UPSTREAM_URL);
    if (!response.ok) throw new Error(`Could not download ${UPSTREAM_URL}: ${response.status}`);
    upstream = JSON.parse((await response.text()).replace(/^﻿/, ""));
  }
  const repo = readJson(join(repoRoot, "build", "eidsca", "EidscaConfig.json"));
  const metadata = readJson(join(repoRoot, "build", "eidsca", "eidsca-test-metadata.json"));

  const differences = diffEidsca({ upstream, repo, metadata });
  const { GITHUB_SERVER_URL, GITHUB_REPOSITORY, GITHUB_RUN_ID } = process.env;
  const workflowUrl = GITHUB_RUN_ID ? `${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}` : undefined;
  const markdown = renderIssueMarkdown(differences, { checkedAt: new Date().toISOString().slice(0, 10), workflowUrl });

  const jsonPath = argument("--json");
  const markdownPath = argument("--markdown");
  if (jsonPath) writeFileSync(jsonPath, JSON.stringify({ count: differences.length, differences }, null, 2) + "\n");
  if (markdownPath) writeFileSync(markdownPath, markdown);
  console.log(`${differences.length} difference(s) between the EIDSCA config and Maester.`);
  if (!jsonPath && !markdownPath && differences.length > 0) console.log(markdown);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
