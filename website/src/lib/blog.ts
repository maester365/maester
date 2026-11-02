// The blog's posts, authors and tags, for the pages in src/pages/blog. URLs match the Docusaurus blog's (and the
// redirects in src/lib/redirects.mjs): /blog/<slug>, /blog/tags/<tag>, /blog/authors/<name>.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { getCollection, type CollectionEntry } from 'astro:content';
import { load as loadYaml } from 'js-yaml';

export type Post = CollectionEntry<'blog'>;

export interface Author {
	id: string;
	name: string;
	title?: string;
	picture?: string;
	url?: string;
	slug: string;
}

export const slugify = (text: string) =>
	text
		.toLowerCase()
		.normalize('NFKD')
		.replace(/[^\w\s-]/g, '')
		.trim()
		.replace(/[\s_]+/g, '-');

type AuthorFile = Record<string, { name: string; title?: string; image_url?: string; url?: string; socials?: Record<string, string> }>;
const authorFile = loadYaml(readFileSync(join(process.cwd(), 'blog/authors.yml'), 'utf8')) as AuthorFile;
export const authors: Record<string, Author> = Object.fromEntries(
	Object.entries(authorFile).map(([id, a]) => [
		id,
		{
			id,
			name: a.name,
			title: a.title,
			picture: a.image_url,
			url: a.url ?? a.socials?.website ?? (a.socials?.github ? `https://github.com/${a.socials.github}` : undefined),
			slug: slugify(a.name),
		},
	]),
);
export const authorsOf = (post: Post) => post.data.authors.map((id) => authors[id]).filter(Boolean);

/** Published posts, newest first. Drafts show only in `astro dev`. */
export async function getPosts(): Promise<Post[]> {
	const posts = await getCollection('blog', (post) => import.meta.env.DEV || !post.data.draft);
	return posts.sort((a, b) => b.data.date.valueOf() - a.data.date.valueOf());
}

// How tags read on the page. Posts write them as short keys (azuredevops, m365); anything not here is capitalised.
const tagNames: Record<string, string> = {
	activedirectory: 'Active Directory',
	ad: 'AD',
	ama: 'AMA',
	azuredevops: 'Azure DevOps',
	bitbucket: 'Bitbucket',
	'code-signing': 'Code signing',
	github: 'GitHub',
	gitlab: 'GitLab',
	m365: 'Microsoft 365',
	'multi-tenant': 'Multi-tenant',
	orca: 'ORCA',
	powershell: 'PowerShell',
	webapp: 'Web app',
	'zero-trust': 'Zero Trust',
};
export const tagName = (tag: string) => tagNames[slugify(tag)] ?? tag.charAt(0).toUpperCase() + tag.slice(1);

/** Tags on nearly every post, which say nothing about one: left out of the blog's topic bar. */
export const broadTags = new Set(['maester', 'blog']);

/** Each tag once, by slug, with how it reads. */
export function tagsOf(posts: Post[]) {
	const tags = new Map<string, { slug: string; label: string; posts: Post[] }>();
	for (const post of posts) {
		for (const tag of post.data.tags) {
			const slug = slugify(tag);
			if (!tags.has(slug)) tags.set(slug, { slug, label: tagName(tag), posts: [] });
			tags.get(slug)!.posts.push(post);
		}
	}
	return [...tags.values()].sort((a, b) => b.posts.length - a.posts.length || a.label.localeCompare(b.label));
}

/** Minutes to read, at 220 words a minute, leaving out code and markup. */
export function readingTime(post: Post) {
	const text = (post.body ?? '')
		.replace(/```[\s\S]*?```/g, ' ')
		.replace(/^import .*$/gm, ' ')
		.replace(/<[^>]+>|\{[^}]*\}/g, ' ');
	return Math.max(1, Math.round(text.split(/\s+/).filter(Boolean).length / 220));
}

export const formatDate = (date: Date) => date.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' });

/** The kind of post (Release, Guide, Event...), shown above its title. */
export const label = (post: Post) => post.data.card_label ?? (post.data.tags.includes('release') ? 'Release' : 'News');
