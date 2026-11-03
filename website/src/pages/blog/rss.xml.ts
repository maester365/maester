// The blog's RSS feed (the Docusaurus feed's /blog/atom.xml redirects here).
import type { APIRoute } from 'astro';
import { authorsOf, getPosts } from '../../lib/blog';

const escape = (text: string) => text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

export const GET: APIRoute = async () => {
	const posts = await getPosts();
	const items = posts.map((post) => {
		const url = `https://maester.dev/blog/${post.id}`;
		return `    <item>
      <title>${escape(post.data.title)}</title>
      <link>${url}</link>
      <guid isPermaLink="true">${url}</guid>
      <pubDate>${post.data.date.toUTCString()}</pubDate>
      <description>${escape(post.data.description)}</description>
${authorsOf(post)
	.map((a) => `      <dc:creator>${escape(a.name)}</dc:creator>`)
	.join('\n')}
${post.data.tags.map((tag) => `      <category>${escape(tag)}</category>`).join('\n')}
    </item>`;
	});
	const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Maester blog</title>
    <link>https://maester.dev/blog</link>
    <atom:link href="https://maester.dev/blog/rss.xml" rel="self" type="application/rss+xml"/>
    <description>Releases, guides and news from the Maester team.</description>
    <language>en</language>
${items.join('\n')}
  </channel>
</rss>
`;
	return new Response(xml, { headers: { 'Content-Type': 'application/rss+xml; charset=utf-8' } });
};
