// How many checks each stable release of Maester shipped, from the git history: src/data/catalog-history.json, which
// git ignores. The home page draws its growth chart from it, with today's count from the catalog explorer's data.
//
// A release's count is read from its tag. Before Maester 3.0 the checks were Pester tests: each `It` block in a
// *.Tests.ps1 file under tests/ is one check (a block that runs for several cases counts once, so the count is a
// little low). From 3.0 each check is a native test file, tests/**/Test.<ID>.ps1, and the packs that ship with
// Maester list their checks in packs/<name>/catalog.json. tests/custom (users' own tests) is never counted.
//
// The build-website workflow checks out the full history with its tags. Without them (a shallow clone) the file
// lists no releases and the chart shows today's count only.
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const websiteRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = join(websiteRoot, "..");
export const catalogHistoryPath = join(websiteRoot, "src", "data", "catalog-history.json");

const git = (...args) => execFileSync("git", args, { cwd: repoRoot, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });

// A stable release tag: 1.2.0 or v1.2.0, not a preview or a release candidate, and not one of the 0.0.x builds of
// the first weeks, whose tests folder held examples as well as checks.
const isRelease = (tag) => {
  const parts = tag.replace(/^v/, "").split(".");
  if (parts.length < 2 || parts.length > 3 || !parts.every((p) => /^\d+$/.test(p))) return false;
  return Number(parts[0]) > 0 || Number(parts[1]) > 0;
};

function countAt(tag) {
  const files = git("ls-tree", "-r", "--name-only", tag, "--", "tests", "packs").split("\n").filter(Boolean);
  const own = (f) => f.startsWith("tests/") && !/^tests\/custom\//i.test(f);
  const native = files.filter((f) => own(f) && /\/Test\.[^/]+\.ps1$/.test(f));
  let builtIn = native.length;
  if (!builtIn) {
    const pester = files.filter((f) => own(f) && /\.tests\.ps1$/i.test(f));
    for (let i = 0; i < pester.length; i += 200) {
      const out = git("grep", "-c", "-E", "^[[:space:]]*It[[:space:]]", tag, "--", ...pester.slice(i, i + 200));
      for (const line of out.split("\n").filter(Boolean)) builtIn += Number(line.split(":").pop());
    }
  }
  let packs = 0;
  for (const f of files.filter((f) => /^packs\/[^/]+\/catalog\.json$/.test(f))) {
    try {
      packs += (JSON.parse(git("show", `${tag}:${f}`)).Tests ?? []).length;
    } catch {
      // A catalog that doesn't parse at that tag is left out.
    }
  }
  return { builtIn, packs };
}

export function writeCatalogHistory() {
  let releases = [];
  try {
    const tags = git("tag", "--list", "--format=%(refname:short)|%(creatordate:short)")
      .split("\n")
      .filter(Boolean)
      .map((line) => line.split("|"))
      .filter(([tag]) => isRelease(tag));
    releases = tags
      .map(([tag, date]) => ({ version: tag.replace(/^v/, ""), date, ...countAt(tag) }))
      .filter((r) => r.builtIn > 0)
      .sort((a, b) => a.date.localeCompare(b.date));
  } catch (error) {
    console.warn(`catalog-history: could not read the release tags: ${error.message}`);
  }
  // eslint-disable-next-line security/detect-non-literal-fs-filename -- a file of this repository
  writeFileSync(catalogHistoryPath, `${JSON.stringify({ $comment: "Written by website/scripts/catalog-history.mjs. Do not edit.", releases }, null, 2)}\n`);
  console.log(`catalog-history: ${releases.length} releases`);
  return releases;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) writeCatalogHistory();
