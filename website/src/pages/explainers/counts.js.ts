// The check counts the explainer videos show in their terminal (public/explainers/how-it-works loads this as
// ../counts.js), from the same module as the pages, so the video can't disagree with them. Played outside the site
// (npx hyperframes preview) the file isn't there, and the numbers in the composition's markup stand.
import type { APIRoute } from 'astro';
import { builtIn, core, zta } from '../../lib/check-counts';

export const GET: APIRoute = () =>
	new Response(`window.__counts = ${JSON.stringify({ builtIn, zta, core })};\n`, {
		headers: { 'Content-Type': 'text/javascript; charset=utf-8' },
	});
