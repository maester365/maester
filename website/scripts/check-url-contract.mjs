// Fails the build if any URL of the old site (src/data/url-contract.txt) is not a page of the new one, or a
// redirect (dist/_redirects) that ends on one. Cloudflare Pages serves docs/intro.html at /docs/intro and
// redirects /docs/intro/ there, so a trailing slash in the contract is ignored.
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const websiteRoot = new URL('..', import.meta.url).pathname;
const dist = join(websiteRoot, 'dist');
const contract = readFileSync(join(websiteRoot, 'src/data/url-contract.txt'), 'utf8')
	.split('\n')
	.map((line) => line.trim())
	.filter((line) => line.startsWith('/'));

const exists = (path) => {
	const clean = decodeURI(path.split('#')[0].replace(/\/$/, ''));
	if (clean === '') return existsSync(join(dist, 'index.html'));
	return existsSync(join(dist, `${clean}.html`)) || existsSync(join(dist, clean, 'index.html')) || (/\.\w+$/.test(clean) && existsSync(join(dist, clean)));
};

const rules = readFileSync(join(dist, '_redirects'), 'utf8')
	.split('\n')
	.filter(Boolean)
	.map((line) => line.split(/\s+/));
const statics = new Map(rules.filter(([from]) => !from.includes('*')).map(([from, to]) => [from, to]));
const splats = rules.filter(([from]) => from.includes('*'));

function follow(path) {
	if (statics.has(path)) return statics.get(path);
	for (const [from, to] of splats) {
		const prefix = from.slice(0, from.indexOf('*'));
		if (path.startsWith(prefix)) return to.replace(':splat', path.slice(prefix.length));
	}
	return null;
}

const failures = [];
for (const raw of contract) {
	let path = raw === '/' ? '/' : raw.replace(/\/$/, '');
	let hops = 0;
	while (!exists(path) && hops < 3) {
		const next = follow(path);
		if (!next) break;
		path = next;
		hops++;
	}
	if (!exists(path)) failures.push(`${raw}${hops ? ` -> ${path}` : ''}`);
}

const dynamic = splats.length;
const fixed = statics.size;
console.log(`URL contract: ${contract.length - failures.length} of ${contract.length} old URLs resolve. ${fixed} static and ${dynamic} dynamic redirects.`);
if (fixed > 2000 || dynamic > 100) failures.push(`Cloudflare Pages allows 2,000 static and 100 dynamic redirects; _redirects has ${fixed} and ${dynamic}.`);
if (failures.length > 0) {
	console.error(`These old URLs no longer resolve:\n${failures.slice(0, 50).map((f) => `  ${f}`).join('\n')}${failures.length > 50 ? `\n  ...and ${failures.length - 50} more` : ''}`);
	process.exit(1);
}
