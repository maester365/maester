// The "Upcoming events" section for the maester.news newsletter: the events of the next six weeks as Markdown, ready
// to paste into an issue. Empty when nothing is coming up. The site rebuilds daily, so it is never more than a day old.
import type { APIRoute } from 'astro';
import { getEvents, newsletterSection } from '../../lib/events';

export const GET: APIRoute = async () => new Response(newsletterSection(await getEvents()), { headers: { 'Content-Type': 'text/markdown; charset=utf-8' } });
