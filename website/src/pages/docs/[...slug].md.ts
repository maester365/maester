// Every docs page as Markdown at its URL plus .md (/docs/installation.md), for "Copy page" and AI tools.
import type { APIRoute, GetStaticPaths } from 'astro';
import { getCollection } from 'astro:content';

export const getStaticPaths: GetStaticPaths = async () => {
	const entries = await getCollection('docs', (e) => e.id.startsWith('docs/') && !e.id.startsWith('docs/2.x') && !e.id.startsWith('docs/sections'));
	return entries.map((entry) => ({ params: { slug: entry.id.replace(/^docs\//, '') }, props: { entry } }));
};

export const GET: APIRoute = ({ props }) => {
	const { entry } = props as { entry: Awaited<ReturnType<typeof getCollection<'docs'>>>[number] };
	const body = (entry.body ?? '')
		// MDX imports and component tags mean nothing outside the site.
		.replace(/^import\s.+$/gm, '')
		.replace(/\{\/\*[\s\S]*?\*\/\}/g, '')
		.replace(/\n{3,}/g, '\n\n')
		.trim();
	const text = `# ${entry.data.title}\n\n${entry.data.description ? `${entry.data.description}\n\n` : ''}Source: https://maester.dev/${entry.id}\n\n${body}\n`;
	return new Response(text, { headers: { 'Content-Type': 'text/markdown; charset=utf-8' } });
};
