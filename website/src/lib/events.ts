// The Maester world tour: talks, workshops and meetups about Maester, from website/events (one YAML file each).
// The events page, the calendar feeds (/events.ics and /events/<id>.ics), /data/events.json and the newsletter
// section (/events/newsletter.md) all read them through these helpers.
//
// The site builds on every merge and once a day (build-website.yaml), so an event moves from Upcoming to Past at
// most a day after it ends.
import { getCollection, type CollectionEntry } from 'astro:content';

export type TourEvent = CollectionEntry<'events'>;

export const SITE = 'https://maester.dev';
export const SUBMIT_URL = 'https://github.com/maester365/maester/issues/new?template=3-event.yml';

export const formatLabels: Record<TourEvent['data']['format'], string> = {
	talk: 'Talk',
	workshop: 'Workshop',
	meetup: 'Meetup',
	webinar: 'Webinar',
	livestream: 'Livestream',
	podcast: 'Podcast',
};

export const attendanceLabels: Record<TourEvent['data']['attendance'], string> = {
	'in-person': 'In person',
	online: 'Online',
	hybrid: 'Hybrid',
};

/** The last day of an event (its start for a one-day event). */
export const lastDay = (e: TourEvent) => e.data.end ?? e.data.start;

/** Today at 00:00 UTC: event dates are calendar days, read as UTC. */
export const today = (now = new Date()) => new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));

/** Every event, soonest first. */
export async function getEvents(): Promise<TourEvent[]> {
	const events = await getCollection('events');
	return events.sort((a, b) => a.data.start.valueOf() - b.data.start.valueOf() || a.id.localeCompare(b.id));
}

/** Events that haven't ended (soonest first) and those that have (most recent first). */
export function splitEvents(events: TourEvent[], now = new Date()) {
	const day = today(now).valueOf();
	return {
		upcoming: events.filter((e) => lastDay(e).valueOf() >= day),
		past: events.filter((e) => lastDay(e).valueOf() < day).reverse(),
	};
}

const fmt = (d: Date, opts: Intl.DateTimeFormatOptions) => d.toLocaleDateString('en-GB', { timeZone: 'UTC', ...opts });

/** "12 March 2027", "12–14 March 2027", "30 March – 2 April 2027". */
export function dateRange(e: TourEvent) {
	const { start } = e.data;
	const end = lastDay(e);
	if (end.valueOf() === start.valueOf()) return fmt(start, { day: 'numeric', month: 'long', year: 'numeric' });
	if (start.getUTCFullYear() !== end.getUTCFullYear()) return `${fmt(start, { day: 'numeric', month: 'long', year: 'numeric' })} – ${fmt(end, { day: 'numeric', month: 'long', year: 'numeric' })}`;
	if (start.getUTCMonth() !== end.getUTCMonth()) return `${fmt(start, { day: 'numeric', month: 'long' })} – ${fmt(end, { day: 'numeric', month: 'long', year: 'numeric' })}`;
	return `${start.getUTCDate()}–${fmt(end, { day: 'numeric', month: 'long', year: 'numeric' })}`;
}

export const monthKey = (d: Date) => fmt(d, { month: 'long', year: 'numeric' });

/** "Antwerp, Belgium", "Online", or "Antwerp, Belgium and online". */
export function placeOf(e: TourEvent) {
	const where = [e.data.city, e.data.country].filter(Boolean).join(', ');
	if (e.data.attendance === 'online' || !where) return 'Online';
	return e.data.attendance === 'hybrid' ? `${where} and online` : where;
}

export const speakerNames = (e: TourEvent) => e.data.speakers.map((s) => s.name).join(', ');

export const eventUrl = (e: TourEvent) => `${SITE}/events#${e.id}`;

/** The places Maester has been and is going, for the page's header. */
export function tourStats(events: TourEvent[]) {
	const countries = new Set(events.map((e) => e.data.country).filter(Boolean));
	const speakers = new Set(events.flatMap((e) => e.data.speakers.map((s) => s.github?.toLowerCase() ?? s.name.toLowerCase())));
	return { events: events.length, countries: countries.size, speakers: speakers.size };
}

// ---- Calendar (iCalendar, RFC 5545) ----

const icsDate = (d: Date) => d.toISOString().slice(0, 10).replace(/-/g, '');
const icsText = (text: string) => text.replace(/\\/g, '\\\\').replace(/\r?\n/g, '\\n').replace(/([,;])/g, '\\$1');

// Lines longer than 75 octets continue on the next line after a space.
function fold(line: string) {
	const bytes = new TextEncoder().encode(line);
	if (bytes.length <= 75) return line;
	const parts: string[] = [];
	let current = '';
	for (const char of line) {
		if (new TextEncoder().encode(current + char).length > (parts.length ? 74 : 75)) {
			parts.push(current);
			current = '';
		}
		current += char;
	}
	parts.push(current);
	return parts.join('\r\n ');
}

function vevent(e: TourEvent, stamp: Date) {
	const end = new Date(lastDay(e).valueOf() + 86_400_000); // DTEND of an all-day event is the day after.
	const details = [
		`${formatLabels[e.data.format]} at ${e.data.event}`,
		e.data.time && `Time: ${e.data.time}`,
		`Speakers: ${speakerNames(e)}`,
		e.data.summary,
		`Event page: ${e.data.url}`,
		e.data.recording && `Recording: ${e.data.recording}`,
	].filter(Boolean);
	return [
		'BEGIN:VEVENT',
		`UID:${e.id}@maester.dev`,
		`DTSTAMP:${stamp.toISOString().replace(/[-:]/g, '').replace(/\.\d+/, '')}`,
		`DTSTART;VALUE=DATE:${icsDate(e.data.start)}`,
		`DTEND;VALUE=DATE:${icsDate(end)}`,
		`SUMMARY:${icsText(`${e.data.title} (${e.data.event})`)}`,
		`DESCRIPTION:${icsText(details.join('\n'))}`,
		`LOCATION:${icsText(placeOf(e))}`,
		`URL:${e.data.url}`,
		'TRANSP:TRANSPARENT',
		'END:VEVENT',
	];
}

export function calendar(events: TourEvent[], name = 'Maester world tour', now = new Date()) {
	const lines = [
		'BEGIN:VCALENDAR',
		'VERSION:2.0',
		'PRODID:-//Maester//World tour//EN',
		'CALSCALE:GREGORIAN',
		'METHOD:PUBLISH',
		`X-WR-CALNAME:${icsText(name)}`,
		'X-WR-CALDESC:Talks\\, workshops and meetups about Maester. maester.dev/events',
		'REFRESH-INTERVAL;VALUE=DURATION:P1D',
		'X-PUBLISHED-TTL:P1D',
		...events.flatMap((e) => vevent(e, now)),
		'END:VCALENDAR',
	];
	return lines.map(fold).join('\r\n') + '\r\n';
}

// ---- Newsletter ----

/**
 * The "Upcoming events" section of maester.news: events that start in the next `days` days (or are on now), as
 * Markdown that pastes into the newsletter. Empty when nothing is coming up, so the issue can leave the section out.
 */
export function newsletterSection(events: TourEvent[], days = 42, now = new Date()) {
	const from = today(now).valueOf();
	const until = from + days * 86_400_000;
	const soon = splitEvents(events, now).upcoming.filter((e) => e.data.start.valueOf() <= until);
	if (!soon.length) return '';
	const items = soon.map((e) => {
		const when = [dateRange(e), e.data.time].filter(Boolean).join(', ');
		return `- **[${e.data.title}](${e.data.url})** at ${e.data.event}\n  ${when} · ${placeOf(e)} · ${speakerNames(e)}`;
	});
	return [
		'## Upcoming events',
		'',
		...items,
		'',
		`See every stop on the [Maester world tour](${SITE}/events), or [add your own event](${SUBMIT_URL}).`,
		'',
	].join('\n');
}
