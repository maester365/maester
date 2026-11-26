// One event as a calendar file, for the "Add to calendar" button on /events.
import type { APIRoute, GetStaticPaths } from 'astro';
import { calendar, getEvents, type TourEvent } from '../../lib/events';

export const getStaticPaths: GetStaticPaths = async () => (await getEvents()).map((event) => ({ params: { id: event.id }, props: { event } }));

export const GET: APIRoute = ({ props }) => {
	const { event } = props as { event: TourEvent };
	return new Response(calendar([event], event.data.title), { headers: { 'Content-Type': 'text/calendar; charset=utf-8' } });
};
