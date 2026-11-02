// Refreshes src/data/test-catalog.json from the test source with Get-MtTest (build/docs/Export-MtTestCatalogForDocs.ps1).
// Needs PowerShell 7 and the Microsoft.Graph.Authentication module. A build without them (such as the Cloudflare
// build) uses the committed catalog, which the update-test-docs workflow refreshes after each merge.
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const repoRoot = fileURLToPath(new URL('../../', import.meta.url));
const output = fileURLToPath(new URL('../src/data/test-catalog.json', import.meta.url));
const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', 'build/docs/Export-MtTestCatalogForDocs.ps1', '-OutputPath', output], {
	cwd: repoRoot,
	stdio: 'inherit',
});
if (result.error || result.status !== 0) {
	console.error(`Could not export the test catalog: ${result.error?.message ?? `pwsh exited with ${result.status}`}`);
	process.exit(1);
}
