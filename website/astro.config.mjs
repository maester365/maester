// @ts-check
import { readdirSync, readFileSync, statSync } from 'node:fs';
import react from '@astrojs/react';
import sitemap from '@astrojs/sitemap';
import starlight from '@astrojs/starlight';
import { defineConfig } from 'astro/config';
import starlightLlmsTxt from 'starlight-llms-txt';
import starlightSidebarTopics from 'starlight-sidebar-topics';
import { rehypeCommandParameters } from './src/lib/rehype-command-parameters.mjs';
import { remarkCommandSyntax } from './src/lib/remark-command-syntax.mjs';
import { commandsSidebar } from './src/lib/command-groups.mjs';
import { redirects } from './src/lib/redirects.mjs';
import { remarkDocLinks } from './src/lib/remark-doc-links.mjs';
import { remarkMermaid } from './src/lib/remark-mermaid.mjs';
import { remarkStripTitle } from './src/lib/remark-strip-title.mjs';

const site = 'https://maester.dev';

// The sidebar of the frozen 2.x docs, from its files (Starlight's autogenerate doesn't match a folder named 2.x).
function archiveSidebar(dir = new URL('./versioned_docs/version-2.3.0/', import.meta.url).pathname, prefix = '') {
	const items = [];
	for (const name of readdirSync(dir).sort()) {
		const path = `${dir}${name}`;
		if (statSync(path).isDirectory()) {
			if (['sections', 'img', 'assets'].includes(name)) continue;
			const children = archiveSidebar(`${path}/`, `${prefix}${name}/`);
			if (children.length) items.push({ label: name.replace(/-/g, ' ').replace(/^\w/, (c) => c.toUpperCase()), collapsed: true, items: children });
		} else if (/\.mdx?$/.test(name)) {
			const title = readFileSync(path, 'utf8').match(/^title:\s*["']?(.+?)["']?\s*$/m)?.[1] ?? name;
			const slug = /^(readme|index)\.mdx?$/i.test(name) ? prefix.replace(/\/$/, '') : `${prefix}${name.replace(/\.mdx?$/, '')}`;
			const item = { label: title, link: `/docs/2.x/${slug}` };
			if (/^(readme|index)\.mdx?$/i.test(name)) items.unshift(item);
			else items.push(item);
		}
	}
	return items;
}

export default defineConfig({
	site,
	trailingSlash: 'never',
	// docs/intro.html is served at /docs/intro: the URL every page and the sitemap use, with no redirect.
	build: { format: 'file' },
	vite: {
		resolve: {
			alias: {
				'@components': new URL('./src/components', import.meta.url).pathname,
				// The React components (test builder, contributors, sponsors) import the site's files as @site/...
				'@site': new URL('.', import.meta.url).pathname.replace(/\/$/, ''),
			},
		},
	},
	markdown: {
		remarkPlugins: [remarkStripTitle, remarkDocLinks, remarkMermaid, remarkCommandSyntax],
		rehypePlugins: [rehypeCommandParameters],
	},
	integrations: [
		sitemap({
			// Not for search engines: the 2.x archive, the Markdown partials, the demo report, and the blog's tag and
			// author lists (thin pages that only repeat post titles).
			filter: (page) => !/\/docs\/2\.x(\/|$)|\/docs\/sections\/|\/demo\/|\/blog\/(tags|authors)\//.test(page),
			lastmod: new Date(),
		}),
		starlight({
			title: 'Maester',
			description: 'Open-source security testing for Microsoft 365, Entra, Azure and Active Directory.',
			logo: { src: './src/assets/maester-mark.svg', alt: 'Maester' },
			favicon: '/favicon.ico',
			customCss: ['./src/styles/theme.css'],
			// The content lives outside src/content/docs, so name its folders: Starlight turns :::note and the other
			// asides into callouts, and adds heading links, only in these.
			markdown: { processedDirs: ['./docs', './.generated/tests', './versioned_docs', './blog'] },
			lastUpdated: false,
			routeMiddleware: './src/routeData.ts',
			editLink: { baseUrl: 'https://github.com/maester365/maester/edit/main/website/' },
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/maester365/maester' },
				{ icon: 'discord', label: 'Discord', href: 'https://discord.maester.dev' },
			],
			components: {
				Head: './src/components/overrides/Head.astro',
				Header: './src/components/overrides/Header.astro',
				PageTitle: './src/components/overrides/PageTitle.astro',
				PageSidebar: './src/components/overrides/PageSidebar.astro',
				Sidebar: './src/components/overrides/Sidebar.astro',
				ThemeSelect: './src/components/overrides/ThemeSelect.astro',
				Footer: './src/components/overrides/Footer.astro',
			},
			expressiveCode: {
				themes: ['github-dark-default', 'github-light-default'],
				styleOverrides: { borderRadius: '0.75rem' },
				// A plain frame (title when given, copy button) rather than a terminal window with three dots.
				defaultProps: { frame: 'code', wrap: true },
				shiki: { langAlias: { PowerShell: 'powershell', Powershell: 'powershell', ps1: 'powershell' } },
			},
			head: [
				{ tag: 'link', attrs: { rel: 'icon', href: '/icon-192.png', type: 'image/png', sizes: '192x192' } },
				{ tag: 'link', attrs: { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' } },
				{ tag: 'link', attrs: { rel: 'manifest', href: '/site.webmanifest' } },
				{ tag: 'meta', attrs: { name: 'twitter:card', content: 'summary_large_image' } },
			],
			plugins: [
				starlightSidebarTopics(
					[
						{
							id: 'guides',
							label: 'Guides',
							link: '/docs/intro',
							icon: 'open-book',
							items: [
								{ label: 'Get started', items: ['docs/intro', 'docs/installation', 'docs/preview', 'docs/upgrading-from-2x', 'docs/updating-tests'] },
								{ label: 'Connect', items: [{ autogenerate: { directory: 'docs/connect-maester' } }] },
								{ label: 'Choose what to run', items: [{ autogenerate: { directory: 'docs/configuration' } }] },
								{ label: 'Results', items: ['docs/export-results', 'docs/result-schema', 'docs/ca-what-if'] },
								{ label: 'Automate', items: [{ autogenerate: { directory: 'docs/monitoring' } }] },
								{ label: 'Alerts', items: [{ autogenerate: { directory: 'docs/alerts' } }] },
								{ label: 'Many tenants', items: [{ autogenerate: { directory: 'docs/multi-tenant' } }] },
								{ label: 'Active Directory', items: ['docs/advanced/active-directory'] },
								{ label: 'Write your own tests', items: [{ autogenerate: { directory: 'docs/writing-tests' } }, { label: 'Test builder', link: '/test-builder' }] },
								{ label: 'Community', items: ['docs/watch', 'docs/contributing', 'docs/agents-and-skills', 'docs/faq'] },
							],
						},
						{
							id: 'tests',
							label: 'Test catalog',
							link: '/docs/tests',
							icon: 'list-format',
							items: [
								{ label: 'All checks', link: '/docs/tests' },
								{
									label: 'Suites',
									items: [
										{ label: 'Maester', link: '/docs/tests/maester' },
										{ label: 'CIS', link: '/docs/tests/cis' },
										{ label: 'CISA SCuBA', link: '/docs/tests/cisa' },
										{ label: 'ASD Essential Eight', link: '/docs/tests/asd' },
										{ label: 'Entra ID SCA (EIDSCA)', link: '/docs/tests/eidsca' },
										{ label: 'ORCA', link: '/docs/tests/orca' },
										{ label: 'Active Directory', link: '/docs/tests/ad' },
									],
								},
								{ label: 'Tags from 2.x', link: '/docs/tests/tags' },
							],
						},
						{
							id: 'builder',
							label: 'Test builder',
							link: '/test-builder',
							icon: 'pencil',
							items: [
								{ label: 'Test builder', link: '/test-builder' },
								{ label: 'Write your own tests', items: [{ autogenerate: { directory: 'docs/writing-tests' } }] },
							],
						},
						{
							id: 'commands',
							label: 'Commands',
							link: '/docs/commands',
							icon: 'seti:powershell',
							// Grouped by job (the module's folders); the sidebar can also list them A to Z (overrides/Sidebar.astro).
							items: commandsSidebar(),
						},
						{
							id: 'packs',
							label: 'Packs',
							link: '/docs/packs',
							icon: 'puzzle',
							items: [
								{ label: 'Maester Packs', items: [{ autogenerate: { directory: 'docs/packs' } }] },
								{ label: 'Browse packs', link: 'https://packs.maester.cloud', attrs: { target: '_blank' } },
							],
						},
						{
							// The frozen 2.x docs: its own sidebar, left out of the header tabs.
							id: 'archive',
							label: '2.x docs',
							link: '/docs/2.x/intro',
							items: [{ label: 'Maester 2.x (archived)', items: archiveSidebar() }],
						},
						// The blog has the site's own layout (src/pages/blog), not the docs sidebar: a tab that links there.
						{ label: 'Blog', link: '/blog', icon: 'document' },
					],
					{
						topics: {
							tests: ['/docs/tests/**/*'],
							builder: ['/test-builder'],
							commands: ['/docs/commands/**/*'],
						},
						// The 2.x archive has its own group in the sidebar (see overrides/Sidebar.astro) but no topic tab.
						exclude: ['/docs/2.x', '/docs/2.x/**/*', '/docs/sections/**/*', '/404'],
					},
				),
				starlightLlmsTxt({
					projectName: 'Maester',
					description:
						'Maester is an open-source PowerShell framework that tests the security configuration of Microsoft 365, Entra ID, Azure and Active Directory against CIS, CISA SCuBA, Microsoft guidance and the Zero Trust Assessment.',
					// llms-small.txt is for a model's context window: the guides and commands, without the 2.x archive, the
					// partials, the blog or the 900 test pages (those are in llms-full.txt and their own set).
					exclude: ['docs/2.x/**', 'docs/sections/**', 'blog/**', 'docs/tests/**'],
					minify: { note: true, tip: true, details: true, whitespace: true },
					customSets: [{ label: 'Test catalog', description: 'Every Maester check, one page each', paths: ['docs/tests/**'] }],
				}),
			],
		}),
		react(),
		redirects(),
	],
});

