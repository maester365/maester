import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const rawVersion = process.argv[2];
const match = rawVersion?.match(/^v?(\d+\.\d+\.\d+)(?:-preview)?$/);

if (!match) {
  console.error("Usage: node build/Update-WebsitePreviewVersion.mjs <version>");
  console.error("Example: node build/Update-WebsitePreviewVersion.mjs 2.1.3-preview");
  process.exit(1);
}

const previewVersion = `${match[1]}-preview`;
const versionConfigFile = join(process.cwd(), "website", "version-config.js");
const config = readFileSync(versionConfigFile, "utf8");
const currentVersionMatch = config.match(/currentVersion:\s*["']([^"']+)["']/);

if (!currentVersionMatch) {
  console.error("Could not find currentVersion in website/version-config.js");
  process.exit(1);
}

writeFileSync(
  versionConfigFile,
  `module.exports = {\n  previewVersion: "${previewVersion}",\n  currentVersion: "${currentVersionMatch[1]}",\n};\n`,
);
