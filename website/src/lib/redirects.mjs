// Writes dist/_redirects (Cloudflare Pages) after the build: every URL the Docusaurus site had that this site
// serves somewhere else. scripts/check-url-contract.mjs checks the result against src/data/url-contract.txt.
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const websiteRoot = process.cwd();

function slugify(text) {
	return text
		.toLowerCase()
		.normalize('NFKD')
		.replace(/[^\w\s-]/g, '')
		.trim()
		.replace(/[\s_]+/g, '-');
}

export function buildRedirects(dist) {
	const exists = (path) => existsSync(join(dist, `${path}.html`)) || existsSync(join(dist, path, 'index.html'));
	const rules = [];
	const add = (from, to) => {
		if (from !== to) rules.push([from, to]);
	};

	// The 3.0 docs were at /docs/next; they are /docs now.
	add('/docs/next', '/docs/intro');
	add('/docs', '/docs/intro');

	// Maester 2.x documented each test's function as a command. In 3.0 those are tests: send each to its test.
	const catalog = JSON.parse(readFileSync(join(websiteRoot, 'src/data/test-catalog.json'), 'utf8'));
	const versions = JSON.parse(readFileSync(join(websiteRoot, 'src/data/versions.json'), 'utf8'));
	const testByFunction = new Map(catalog.Tests.filter((t) => t.FunctionName).map((t) => [t.FunctionName, t.Id]));
	for (const name of Object.keys(versions.commands)) {
		if (exists(`/docs/commands/${name}`)) continue;
		const test = testByFunction.get(name);
		if (test) add(`/docs/commands/${name}`, `/docs/tests/${test}`);
		else if (exists(`/docs/2.x/commands/${name}`)) add(`/docs/commands/${name}`, `/docs/2.x/commands/${name}`);
		else add(`/docs/commands/${name}`, '/docs/commands');
	}

	// 2.x guide pages that 3.0 no longer has: the archived copy.
	const contract = readFileSync(join(websiteRoot, 'src/data/url-contract.txt'), 'utf8')
		.split('\n')
		.map((line) => line.trim().replace(/\/$/, ''))
		.filter((line) => line.startsWith('/'));
	for (const path of contract) {
		if (!path.startsWith('/docs/') || path.startsWith('/docs/next/') || path.startsWith('/docs/commands/') || path.startsWith('/docs/tests/')) continue;
		if (exists(path)) continue;
		const archived = path.replace(/^\/docs\//, '/docs/2.x/');
		if (exists(archived)) add(path, archived);
	}

	// Blog: Docusaurus paths this blog doesn't have (it lists every post on one page).
	add('/blog/page/2', '/blog');
	add('/blog/archive', '/blog');
	add('/blog/authors', '/blog');
	if (!exists('/blog/tags')) add('/blog/tags', '/blog');
	add('/blog/atom.xml', '/blog/rss.xml');
	const authors = Object.entries(
		Object.fromEntries(
			readFileSync(join(websiteRoot, 'blog/authors.yml'), 'utf8')
				.split('\n')
				.reduce((acc, line) => {
					const id = line.match(/^([a-z0-9_-]+):\s*$/i)?.[1];
					if (id) acc.push([id, '']);
					const name = line.match(/^\s+name:\s*(.+)$/)?.[1];
					if (name && acc.length) acc[acc.length - 1][1] = name.replace(/^["']|["']$/g, '');
					return acc;
				}, []),
		),
	);
	for (const [id, name] of authors) {
		const slug = slugify(name);
		if (exists(`/blog/authors/${slug}`)) add(`/blog/authors/${id}`, `/blog/authors/${slug}`);
	}
	for (const [from, to] of [
		['azure-dev-ops', 'azuredevops'],
		['bit-bucket', 'bitbucket'],
		['m-365', 'm365'],
		['web-app', 'webapp'],
	]) {
		add(`/blog/tags/${from}`, `/blog/tags/${to}`);
	}

	// Pages that are gone.
	add('/markdown-page', '/');
	add('/search', '/docs/intro');

	// The whole preview tree, after the specific rules above. Cloudflare applies the first match.
	const lines = rules.map(([from, to]) => `${from} ${to} 301`);
	lines.push('/docs/next/* /docs/:splat 301');
	return lines;
}

// With build.format 'file', Astro.url ends in .html at build time, and Starlight uses it for the canonical, og:url and
// its own links (sidebar, pagination, logo). The site serves every page without the extension (Cloudflare Pages
// redirects /x.html to /x), so the URLs in the HTML must not have it either.
function fixPageUrls(dist) {
	const pattern = /(<link rel="canonical" href="|<meta property="og:url" content=")(https:\/\/maester\.dev\/[^"]*?)(?:index)?\.html"/g;
	const links = /href="(\/(?!explainers\/|demo\/)[^"#?]*?)(?:index)?\.html([#?][^"]*)?"/g;
	let fixed = 0;
	const walk = (dir) => {
		for (const entry of readdirSync(dir, { withFileTypes: true })) {
			const path = join(dir, entry.name);
			if (entry.isDirectory()) walk(path);
			else if (entry.name.endsWith('.html')) {
				const html = readFileSync(path, 'utf8');
				const updated = html
					.replace(links, (_, path, rest = '') => `href="${path.replace(/(.)\/$/, '$1') || '/'}${rest}"`)
					.replace(pattern, (_, attr, url) => `${attr}${url === 'https://maester.dev/' ? url : url.replace(/\/$/, '')}"`);
				if (updated !== html) {
					writeFileSync(path, updated);
					fixed++;
				}
			}
		}
	};
	walk(dist);
	return fixed;
}

export function redirects() {
	return {
		name: 'maester-redirects',
		hooks: {
			'astro:build:done': ({ dir, logger }) => {
				const dist = fileURLToPath(dir);
				const lines = buildRedirects(dist);
				writeFileSync(join(dist, '_redirects'), `${lines.join('\n')}\n`);
				logger.info(`Wrote ${lines.length} redirects to _redirects.`);
				logger.info(`Removed .html from the links and canonical URLs of ${fixPageUrls(dist)} pages.`);
			},
		},
	};
}

