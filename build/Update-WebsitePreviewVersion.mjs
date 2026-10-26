import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const rawVersion = process.argv[2];
// The site shows the release a preview leads to, without the preview counter: 3.1.0-preview03 and 3.0.0-rc01 are
// shown as 3.1.0-preview and 3.0.0-preview.
const match = rawVersion?.match(/^v?(\d+\.\d+\.\d+)(?:-(?:preview|rc)\d*)?$/);

if (!match) {
  console.error("Usage: node build/Update-WebsitePreviewVersion.mjs <version>");
  console.error("Example: node build/Update-WebsitePreviewVersion.mjs 3.0.0-preview2");
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
