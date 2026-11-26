// The Maester world tour as a calendar people subscribe to (webcal://maester.dev/events.ics): every event, past and
// upcoming, as an all-day entry. Calendar apps refresh it about once a day.
import type { APIRoute } from 'astro';
import { calendar, getEvents } from '../lib/events';

export const GET: APIRoute = async () => new Response(calendar(await getEvents()), { headers: { 'Content-Type': 'text/calendar; charset=utf-8' } });
