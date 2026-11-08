// Generates the data the site is built from, which is not kept in git: the test catalog (src/data/test-catalog.json),
// the command reference (docs/commands/*.mdx), the contributor credits (src/data/contributors.json) and the sponsors
// (src/data/sponsors.json, public/readme/sponsors*.svg). Runs before `npm run dev` and `npm run build`.
//
// Each file is generated only when it is missing, so a second `npm run dev` starts at once; `npm run refresh-data`
// (--refresh) regenerates them all, for example after changing a test or a command's help. The catalog and the
// command reference need PowerShell 7 and the Microsoft.Graph.Authentication module. The build-website workflow
// runs this in a fresh checkout, so every deploy of maester.dev is built from the source of that commit.
import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const websiteRoot = fileURLToPath(new URL('..', import.meta.url));
const repoRoot = fileURLToPath(new URL('../..', import.meta.url));
const refresh = process.argv.includes('--refresh');
const at = (path) => fileURLToPath(new URL(`../${path}`, import.meta.url));
const missing = (path) => refresh || !existsSync(at(path));

function run(label, command, args, cwd, cleanUp) {
	console.log(`prepare-data: ${label}`);
	const result = spawnSync(command, args, { cwd, stdio: 'inherit' });
	if (result.error || result.status !== 0) {
		cleanUp?.();
		const reason = result.error?.code === 'ENOENT' ? `${command} is not installed` : (result.error?.message ?? `${command} exited with ${result.status}`);
		console.error(`prepare-data: could not ${label.toLowerCase()}: ${reason}.`);
		if (command === 'pwsh') console.error('It needs PowerShell 7 and the Microsoft.Graph.Authentication module: https://maester.dev/docs/contributing');
		process.exit(1);
	}
}

const pwsh = (script, ...args) => ['-NoProfile', '-NonInteractive', '-File', script, ...args];

if (missing('src/data/test-catalog.json')) {
	run('Export the test catalog', 'pwsh', pwsh('build/docs/Export-MtTestCatalogForDocs.ps1', '-OutputPath', at('src/data/test-catalog.json')), repoRoot);
}

const commandPages = () => readdirSync(at('docs/commands')).filter((name) => name.endsWith('.mdx') && name !== 'readme.mdx');
// A failed run can leave some pages half converted and the index page (readme.mdx, kept in git) deleted. Remove the
// pages, so the next run generates them again, and put back the index page as it was before the run, edits included.
const commandIndex = at('docs/commands/readme.mdx');
if (refresh || commandPages().length === 0) {
	const index = readFileSync(commandIndex);
	run('Generate the command reference', 'pwsh', pwsh('build/Update-CommandReference.ps1'), repoRoot, () => {
		try {
			for (const name of commandPages()) rmSync(at(`docs/commands/${name}`), { force: true });
		} finally {
			writeFileSync(commandIndex, index);
		}
	});
}

// The test pages, the contributor credits and the catalog explorer's data; the site's content loader writes the test
// pages again on each build.
if (missing('src/data/contributors.json') || missing('src/data/explorer.json')) {
	run('Credit the contributors', process.execPath, ['scripts/generate-test-docs.mjs'], websiteRoot);
}

if (missing('src/data/sponsors.json') || missing('public/readme/sponsors.svg')) {
	run('Look up the sponsors', process.execPath, ['scripts/sponsors.mjs'], websiteRoot);
}
