// The site's main menu: the top bar on every page (components/SiteHeaderBar.astro) and, on phones, the docs drawer
// (components/overrides/Sidebar.astro), where Starlight's own menu button replaces the top bar's.
export const siteNav = [
	{ label: 'Docs', href: '/docs/intro' },
	{ label: 'Test catalog', href: '/docs/tests' },
	{ label: 'Blog', href: '/blog' },
	{ label: 'Contributors', href: '/contributors' },
	{ label: 'Pricing', href: '/pricing' },
	{ label: 'Manifesto', href: 'https://maester.cloud/manifesto' },
	{ label: 'Packs', href: 'https://packs.maester.cloud' },
	{ label: 'Maester Cloud ↗', href: 'https://maester.cloud' },
];

/** A page's path without the `.html` the build adds (build.format 'file') or a trailing slash. */
export const pagePath = (pathname: string) => pathname.replace(/(index)?\.html$/, '').replace(/(.)\/$/, '$1') || '/';

// Whether a path is the item's page or below it, segment by segment, so /blog does not claim /blogger.
const under = (path: string, base: string) => path === base || path.startsWith(`${base}/`);

/** Whether a menu item is the page's own: every docs page belongs to Docs, except the test catalog's own pages. */
export const isCurrentNav = (pathname: string, href: string) => {
	const path = pagePath(pathname);
	if (href === '/docs/tests') return under(path, '/docs/tests');
	if (href === '/docs/intro') return under(path, '/docs') && !under(path, '/docs/tests');
	return href.startsWith('/') && under(path, href);
};
