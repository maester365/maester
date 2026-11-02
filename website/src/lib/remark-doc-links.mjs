// Turns links to other Markdown files ("./configuration/overview.md#selection") into the URL of that page,
// so the docs read the same on GitHub and on the site.
import { existsSync } from 'node:fs';
import { dirname, relative, resolve, sep } from 'node:path';

const websiteRoot = process.cwd();
const roots = [
	{ dir: resolve(websiteRoot, 'docs'), url: '/docs' },
	{ dir: resolve(websiteRoot, 'versioned_docs', 'version-2.3.0'), url: '/docs/2.x' },
];

function urlFor(target) {
	for (const root of roots) {
		const rel = relative(root.dir, target);
		if (rel.startsWith('..')) continue;
		const parts = rel.replace(/\.mdx?$/, '').split(sep);
		if (/^(readme|index)$/i.test(parts.at(-1))) parts.pop();
		// A 2.x command page that is now a test redirects from its current URL.
		if (root.url === '/docs/2.x' && parts[0] === 'commands' && !existsSync(target)) return `/docs/commands/${parts.slice(1).join('/')}`;
		return [root.url, ...parts].join('/');
	}
	return null;
}

export function remarkDocLinks() {
	return (tree, file) => {
		if (!file.path) return;
		const from = dirname(file.path);
		const visit = (node) => {
			if ((node.type === 'link' || node.type === 'definition') && typeof node.url === 'string') {
				const match = node.url.match(/^(?!\w+:|\/|#)([^#?]+\.mdx?)(#.*)?$/);
				if (match) {
					let target = resolve(from, decodeURI(match[1]));
					if (!existsSync(target)) {
						const other = target.endsWith('.md') ? `${target}x` : target.replace(/\.mdx$/, '.md');
						if (existsSync(other)) target = other;
					}
					const url = urlFor(target);
					if (url) node.url = url + (match[2] ?? '');
				}
			}
			for (const child of node.children ?? []) visit(child);
		};
		visit(tree);
	};
}
