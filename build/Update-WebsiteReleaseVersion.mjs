import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const rawVersion = process.argv[2];
const match = rawVersion?.match(/^v?(\d+)\.(\d+)\.(\d+)$/);

if (!match) {
  console.error("Usage: node build/Update-WebsiteReleaseVersion.mjs <version>");
  console.error("Example: node build/Update-WebsiteReleaseVersion.mjs 2.1.0");
  process.exit(1);
}

const [, major, minor, patch] = match;
const currentVersion = `${major}.${minor}.${patch}`;
const previewVersion = `${major}.${minor}.${Number(patch) + 1}-preview`;

const repoRoot = process.cwd();
const websiteRoot = join(repoRoot, "website");
const versionedDocsRoot = join(websiteRoot, "versioned_docs");
const versionedSidebarsRoot = join(websiteRoot, "versioned_sidebars");
const currentDocsDirectory = join(versionedDocsRoot, `version-${currentVersion}`);
const currentSidebarFile = join(versionedSidebarsRoot, `version-${currentVersion}-sidebars.json`);
const versionsFile = join(websiteRoot, "versions.json");
const versionConfigFile = join(websiteRoot, "version-config.js");

let versions = [];
if (existsSync(versionsFile)) {
  versions = JSON.parse(readFileSync(versionsFile, "utf8"));
}

if (!existsSync(currentDocsDirectory)) {
  writeFileSync(versionsFile, `${JSON.stringify(versions.filter((version) => version !== currentVersion), null, 2)}\n`);
  execFileSync("npm", ["run", "docusaurus", "--", "docs:version", currentVersion], {
    cwd: websiteRoot,
    stdio: "inherit",
  });
}

if (existsSync(versionedDocsRoot)) {
  for (const entry of readdirSync(versionedDocsRoot, { withFileTypes: true })) {
    if (entry.isDirectory() && entry.name !== `version-${currentVersion}`) {
      rmSync(join(versionedDocsRoot, entry.name), { recursive: true, force: true });
    }
  }
}

if (existsSync(versionedSidebarsRoot)) {
  for (const entry of readdirSync(versionedSidebarsRoot, { withFileTypes: true })) {
    if (entry.isFile() && entry.name !== `version-${currentVersion}-sidebars.json`) {
      rmSync(join(versionedSidebarsRoot, entry.name), { force: true });
    }
  }
}

writeFileSync(versionsFile, `${JSON.stringify([currentVersion], null, 2)}\n`);
writeFileSync(
  versionConfigFile,
  `module.exports = {\n  previewVersion: "${previewVersion}",\n  currentVersion: "${currentVersion}",\n};\n`,
);
