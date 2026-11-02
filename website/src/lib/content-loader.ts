// The docs collection: the guides and command reference in website/docs, the generated test pages and the frozen
// 2.x docs (the blog is a collection of its own, see content.config.ts). Each source keeps its own folder; this loader gives every page the
// URL it had on the Docusaurus site.
import { execFileSync } from 'node:child_process';
import { glob, type Loader, type LoaderContext } from 'astro/loaders';

type Owns = (id: string) => boolean;

// A glob loader removes the entries it did not see on its last pass. Each source sees only its own entries,
// so the sources don't remove each other's pages.
function scoped(context: LoaderContext, owns: Owns): LoaderContext {
	const store = new Proxy(context.store, {
		get(target, property, receiver) {
			if (property === 'keys') return () => target.keys().filter(owns);
			if (property === 'values') return () => target.values().filter((entry) => owns(entry.id));
			if (property === 'entries') return () => target.entries().filter(([id]) => owns(id));
			if (property === 'clear') return () => target.keys().filter(owns).forEach((id) => target.delete(id));
			const value = Reflect.get(target, property, receiver);
			return typeof value === 'function' ? value.bind(target) : value;
		},
	});
	return { ...context, store };
}

// docs/connect-maester/readme.md -> connect-maester, like Docusaurus: a readme or index is its folder's page.
function pathId(entry: string): string {
	const parts = entry.replace(/\.mdx?$/, '').split('/');
	if (parts.length > 0 && /^(readme|index)$/i.test(parts.at(-1)!)) parts.pop();
	return parts.join('/');
}

const join = (...parts: string[]) => parts.filter(Boolean).join('/');
const isTest = (id: string) => id === 'docs/tests' || id.startsWith('docs/tests/');
const isArchive = (id: string) => id === 'docs/2.x' || id.startsWith('docs/2.x/');

const sources: { owns: Owns; loader: Loader }[] = [
	{
		// Starlight's 404 page uses the entry with the id 404.
		owns: (id) => id === '404',
		loader: glob({ pattern: '404.md', base: './src/content', generateId: () => '404' }),
	},
	{
		owns: (id) => id.startsWith('docs/') && !isTest(id) && !isArchive(id),
		loader: glob({
			pattern: ['**/*.{md,mdx}'],
			base: './docs',
			generateId: ({ entry }) => join('docs', pathId(entry)),
		}),
	},
	{
		owns: isTest,
		loader: glob({
			pattern: ['**/*.{md,mdx}'],
			base: './.generated/tests',
			generateId: ({ entry, data }) => (typeof data.slug === 'string' ? data.slug : join('docs/tests', pathId(entry))),
		}),
	},
	{
		owns: isArchive,
		loader: glob({
			pattern: ['**/*.{md,mdx}'],
			base: './versioned_docs/version-2.3.0',
			generateId: ({ entry }) => join('docs/2.x', pathId(entry)),
		}),
	},
];

export function maesterLoader(): Loader {
	return {
		name: 'maester-content',
		async load(context) {
			// The test pages are written from src/data/test-catalog.json before they are loaded.
			execFileSync(process.execPath, ['scripts/generate-test-docs.mjs'], { stdio: 'inherit' });
			for (const { owns, loader } of sources) await loader.load(scoped(context, owns));
		},
	};
}
