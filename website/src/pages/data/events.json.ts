// The Maester world tour as data, for the newsletter and anything else that lists Maester events.
import type { APIRoute } from 'astro';
import { eventUrl, getEvents, lastDay, placeOf, splitEvents } from '../../lib/events';

export const GET: APIRoute = async () => {
	const { upcoming, past } = splitEvents(await getEvents());
	const row = (e: Awaited<ReturnType<typeof getEvents>>[number]) => ({
		id: e.id,
		...e.data,
		start: e.data.start.toISOString().slice(0, 10),
		end: lastDay(e).toISOString().slice(0, 10),
		place: placeOf(e),
		page: eventUrl(e),
		calendar: `https://maester.dev/events/${e.id}.ics`,
	});
	return new Response(JSON.stringify({ generated: new Date().toISOString(), upcoming: upcoming.map(row), past: past.map(row) }, null, 2), {
		headers: { 'Content-Type': 'application/json' },
	});
};
