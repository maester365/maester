// Starlight route middleware: per-page fixes that depend on where a page sits.
import { defineRouteMiddleware } from '@astrojs/starlight/route-data';
import { commandGroups } from './lib/command-groups.mjs';
import { summarize } from './lib/summary.mjs';

export const onRequest = defineRouteMiddleware((context) => {
	const route = context.locals.starlightRoute;
	const { id, entry } = route;
	const data = entry.data as Record<string, any>;
	const isArchive = id === 'docs/2.x' || id.startsWith('docs/2.x/');
	const isPartial = id.startsWith('docs/sections/');

	// The 2.x archive and the Markdown partials stay out of search.
	if (isArchive || isPartial) data.pagefind = false;

	// A command page's headings are SYNOPSIS, SYNTAX, EXAMPLE 1…23, -Parameter…: list only the sections.
	if (/^docs\/commands\/[^/]+$/.test(id) && route.toc) route.toc.items = route.toc.items.map((item) => ({ ...item, children: [] }));
	// The commands overview lists its groups (drawn by CommandList.astro, so not headings of the page's own).
	if (id === 'docs/commands' && route.toc) {
		route.toc.items = [...route.toc.items, ...commandGroups().map((g) => ({ depth: 2, slug: g.id, text: g.label, children: [] }))];
	}

	// A check's page has no contents list, but its right column holds what the check maps to (catalog/CheckRail.astro,
	// drawn by overrides/PageSidebar.astro): Starlight draws that column only for a page with a contents list.
	if (data.maester?.kind === 'test' && !route.toc) route.toc = { minHeadingLevel: 2, maxHeadingLevel: 2, items: [] };

	// The blog's list pages.
	if (/^blog(\/\d+)?$/.test(id)) {
		data.description = 'Releases, new checks and how-tos from the Maester team: open-source security testing for Microsoft 365, Entra, Azure and Active Directory.';
		setDescription(route, data.description);
	}

	// A page without a description of its own gets its first paragraph, not the site's description.
	if (!data.description && entry.body) {
		const description = summarize(entry.body);
		if (description) {
			data.description = description;
			setDescription(route, description);
		}
	}
});

function setDescription(route: { head: { attrs?: Record<string, string | boolean | undefined> }[] }, description: string) {
	for (const tag of route.head) {
		const attrs = tag.attrs ?? {};
		if (attrs.name === 'description' || attrs.property === 'og:description' || attrs.name === 'twitter:description') attrs.content = description;
	}
}
