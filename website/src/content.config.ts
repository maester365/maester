import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';
import { docsSchema } from '@astrojs/starlight/schema';
import { topicSchema } from 'starlight-sidebar-topics/schema';
import { maesterLoader } from './lib/content-loader';

export const collections = {
	docs: defineCollection({
		loader: maesterLoader(),
		schema: docsSchema({
			extend: () =>
				topicSchema
					.extend({
						// Facts about a generated test or command page, for its version notes.
						maester: z
							.object({
								kind: z.enum(['test', 'command']),
								id: z.string(),
								suite: z.string().optional(),
								severity: z.string().optional(),
								product: z.string().optional(),
								feature: z.string().optional(),
								previewOnly: z.boolean().default(false),
								previewCheck: z.boolean().default(false),
							})
							.optional(),
						// A guide section or page that only applies from this release: see the versions guide.
						since: z.string().optional(),
					}),
		}),
	}),
	// The blog, in website/blog: one folder per post (index.md or index.mdx and its images), at /blog/<slug>.
	// Posts are their own collection, outside the docs, so they get the site's own layout rather than the docs sidebar.
	blog: defineCollection({
		loader: glob({ pattern: ['*/index.{md,mdx}'], base: './blog', generateId: ({ entry, data }) => (typeof data.slug === 'string' ? data.slug : entry.split('/')[0]) }),
		schema: ({ image }) =>
			z.object({
				title: z.string(),
				description: z.string(),
				date: z.coerce.date(),
				authors: z.union([z.string(), z.string().array()]).transform((a) => (Array.isArray(a) ? a : [a])),
				tags: z.string().array().default([]),
				// The social card (scripts/blog-cards), also the post's picture on the blog's cards.
				image: image().optional(),
				card_headline: z.string().optional(),
				card_label: z.string().optional(),
				excerpt: z.string().optional(),
				draft: z.boolean().default(false),
			}),
	}),
};
