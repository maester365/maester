import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import test from 'node:test';

test('retired native tests redirect to their surviving checks without removing URL-contract entries', async () => {
	const previous = process.cwd();
	const fixture = mkdtempSync(join(tmpdir(), 'maester-redirects-'));
	const source = new URL('../../src/lib/redirects.mjs', import.meta.url);
	const registry = readFileSync(new URL('../../../build/golden/native-test-replacements.psd1', import.meta.url), 'utf8');
	const replacements = Object.fromEntries([...registry.matchAll(/'([^']+)'\s*=\s*'([^']+)'/g)].map((match) => [match[1], match[2]]));
	const contract = readFileSync(new URL('../../src/data/url-contract.txt', import.meta.url), 'utf8');
	try {
		mkdirSync(join(fixture, 'src/data'), { recursive: true });
		mkdirSync(join(fixture, 'blog'), { recursive: true });
		mkdirSync(join(fixture, 'dist/docs/tests'), { recursive: true });
		writeFileSync(join(fixture, 'src/data/test-catalog.json'), JSON.stringify({ Tests: [], TestReplacements: replacements }));
		writeFileSync(join(fixture, 'src/data/versions.json'), JSON.stringify({ commands: {} }));
		writeFileSync(join(fixture, 'src/data/url-contract.txt'), contract);
		writeFileSync(join(fixture, 'blog/authors.yml'), '');
		for (const replacement of new Set(Object.values(replacements))) {
			writeFileSync(join(fixture, `dist/docs/tests/${replacement}.html`), 'survivor');
		}
		process.chdir(fixture);
		const { buildRedirects } = await import(pathToFileURL(source.pathname).href + '?retired-test-fixture');
		const rules = buildRedirects(join(fixture, 'dist'));
		assert.ok(rules.includes('/docs/tests/AD-GPOREP-16 /docs/tests/AD-GPOREP-15 301'));
		assert.ok(rules.includes('/docs/tests/AD-GPOS-01 /docs/tests/AD-GPO-01 301'));
		assert.ok(rules.includes('/docs/next/* /docs/:splat 301'));
		const redirects = new Map(rules.map((line) => line.split(/\s+/).slice(0, 2)));
		let verified = 0;
		for (const path of contract.split('\n').map((line) => line.trim())) {
			const id = path.match(/^\/docs\/(?:next\/)?tests\/([^/]+)$/)?.[1];
			if (!replacements[id]) continue;
			const current = path.replace(/^\/docs\/next\//, '/docs/');
			assert.equal(redirects.get(current), `/docs/tests/${replacements[id]}`, path);
			verified++;
		}
		assert.ok(verified >= 36, 'real contract must exercise the retired AD test URLs in both URL trees');
		assert.equal(readFileSync(join(fixture, 'src/data/url-contract.txt'), 'utf8'), contract);
	} finally {
		process.chdir(previous);
		rmSync(fixture, { recursive: true, force: true });
	}
});
