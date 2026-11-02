// Run by the publish-module workflows for every stable release. It tells the website which version is stable
// and which preview comes next (website/version-config.js), and records in website/src/data/versions.json the
// tests, commands and parameters this release contains, so the site stops marking them as preview-only.
//
// Usage (from the repository root, after `npm ci` and `npm run export-catalog` in website/):
//   node build/Update-WebsiteReleaseVersion.mjs 3.0.0
//
// A new major version (4.0.0) also needs the docs of the old one archived: copy website/docs to
// website/versioned_docs/version-3.x and serve it at /docs/3.x (see website/src/lib/content-loader.ts).
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { join } from "node:path";

const rawVersion = process.argv[2];
const match = rawVersion?.match(/^v?(\d+)\.(\d+)\.(\d+)$/);

if (!match) {
  console.error("Usage: node build/Update-WebsiteReleaseVersion.mjs <version>");
  console.error("Example: node build/Update-WebsiteReleaseVersion.mjs 3.0.0");
  process.exit(1);
}

const [, major, minor, patch] = match;
const currentVersion = `${major}.${minor}.${patch}`;
// Previews after a release are prereleases of the next minor version: after 3.0.0 they are 3.1.0-preview1, 3.1.0-preview2.
const previewVersion = `${major}.${Number(minor) + 1}.0-preview`;
const websiteRoot = join(process.cwd(), "website");

writeFileSync(
  join(websiteRoot, "version-config.js"),
  `module.exports = {\n  previewVersion: "${previewVersion}",\n  currentVersion: "${currentVersion}",\n};\n`,
);
execFileSync(process.execPath, ["scripts/update-versions.mjs", currentVersion], { cwd: websiteRoot, stdio: "inherit" });
