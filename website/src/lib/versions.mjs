// The two release channels the site documents, and what each one contains.
//
// website/version-config.js holds the current stable and preview versions; the publish-module workflows update
// it. website/src/data/versions.json holds the release each test, command and parameter first shipped in
// (scripts/update-versions.mjs). Anything not in versions.json is only in the preview.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

// The build runs from website/; bundled pages can't locate files relative to this module.
const websiteRoot = process.cwd();
const config = readFileSync(resolve(websiteRoot, 'version-config.js'), 'utf8');
const read = (key) => config.match(new RegExp(`${key}:\\s*["']([^"']+)["']`))?.[1] ?? '';

export const stableVersion = read('currentVersion');
// 3.1.0-preview: the release the preview leads to.
export const previewVersion = read('previewVersion');
// 3.1: how the site names the preview in marks such as "New in 3.1".
export const previewLabel = previewVersion.replace(/^(\d+\.\d+)\..*$/, '$1');

const history = JSON.parse(readFileSync(resolve(websiteRoot, 'src/data/versions.json'), 'utf8'));

export const releasedTests = new Set(Object.keys(history.tests));

/** @param {string} name */
export function commandHistory(name) {
	const entry = history.commands[name];
	return entry ? { since: entry.since, parameters: new Set(Object.keys(entry.parameters ?? {})) } : null;
}
