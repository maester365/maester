#!/usr/bin/env node
// Turns an event issue (.github/ISSUE_TEMPLATE/3-event.yml) into a Maester world tour file in website/events.
// The event-submissions workflow runs it when a maintainer approves the issue, then opens a pull request.
//
//   ISSUE_BODY=... ISSUE_NUMBER=123 node scripts/events/issue-to-event.mjs [--check]
//
// The issue body is untrusted: every value is checked here, written as a JSON string (which is valid YAML) and
// checked again by the events schema in src/content.config.ts when the site builds. --check validates without
// writing. On a problem it prints the reasons, writes them to $EVENT_ERRORS_FILE when set, and exits 1.
import { appendFileSync, existsSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const eventsDir = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'events');

// The form's labels, as GitHub writes them into the issue body (### Label).
const fields = {
	'Session title': 'title',
	'Event name': 'event',
	Date: 'start',
	'Last day': 'end',
	'Time and time zone': 'time',
	Format: 'format',
	'Where can people join?': 'attendance',
	City: 'city',
	Country: 'country',
	Language: 'language',
	Speakers: 'speakers',
	'Event or registration link': 'url',
	Summary: 'summary',
	'Recording link': 'recording',
	'Slides link': 'slides',
};

/** The form's answers by field, without GitHub's "_No response_". */
export function readForm(body) {
	const values = {};
	const sections = `\n${body.replace(/\r\n/g, '\n')}`.split(/\n### /).slice(1);
	for (const section of sections) {
		const [label, ...rest] = section.split('\n');
		const key = fields[label.trim()];
		if (!key) continue;
		const value = rest.join('\n').trim();
		if (value && value !== '_No response_') values[key] = value;
	}
	return values;
}

const oneLine = (text) => text.replace(/\s+/g, ' ').trim();
const isDate = (text) => /^\d{4}-\d{2}-\d{2}$/.test(text) && !Number.isNaN(Date.parse(`${text}T00:00:00Z`)) && new Date(`${text}T00:00:00Z`).toISOString().startsWith(text);
const isHttps = (text) => {
	try {
		const url = new URL(text);
		return url.protocol === 'https:' && !url.username && !url.password;
	} catch {
		return false;
	}
};

/** The event, or the list of what is wrong with the form. */
export function toEvent(form, issue) {
	const errors = [];
	const event = {};
	const text = (key, label, { required = false, max = 120, min = 0 } = {}) => {
		const value = form[key] ? oneLine(form[key]) : '';
		if (!value) {
			if (required) errors.push(`**${label}** is required.`);
			return;
		}
		if (value.length < min || value.length > max) errors.push(`**${label}** must be ${min ? `${min} to ` : 'at most '}${max} characters.`);
		else event[key] = value;
	};
	const link = (key, label, required = false) => {
		const value = form[key]?.trim();
		if (!value) {
			if (required) errors.push(`**${label}** is required.`);
			return;
		}
		if (!isHttps(value)) errors.push(`**${label}** must be a single https:// link.`);
		else event[key] = value;
	};

	text('title', 'Session title', { required: true, min: 3, max: 160 });
	text('event', 'Event name', { required: true, min: 2, max: 120 });

	const start = form.start?.trim();
	if (!start || !isDate(start)) errors.push('**Date** must be a date like 2027-03-16.');
	else event.start = start;
	const end = form.end?.trim();
	if (end) {
		if (!isDate(end)) errors.push('**Last day** must be a date like 2027-03-18.');
		else if (event.start && end < event.start) errors.push('**Last day** is before **Date**.');
		else if (end !== event.start) event.end = end;
	}
	text('time', 'Time and time zone', { max: 60 });

	const format = form.format?.trim().toLowerCase();
	if (!['talk', 'workshop', 'meetup', 'webinar', 'livestream', 'podcast'].includes(format)) errors.push('**Format** must be one of the listed options.');
	else event.format = format;
	const attendance = { 'in person': 'in-person', online: 'online', 'hybrid (in person and online)': 'hybrid' }[form.attendance?.trim().toLowerCase()];
	if (!attendance) errors.push('**Where can people join?** must be one of the listed options.');
	else event.attendance = attendance;

	text('city', 'City', { max: 80 });
	text('country', 'Country', { max: 60 });
	if (attendance && attendance !== 'online' && (!event.city || !event.country)) errors.push('An in-person or hybrid event needs a **City** and **Country**.');
	if (attendance === 'online') {
		delete event.city;
		delete event.country;
	}
	text('language', 'Language', { max: 40 });
	if (event.language && /^english$/i.test(event.language)) delete event.language;

	const speakers = (form.speakers ?? '')
		.split('\n')
		.map((line) => line.replace(/^\s*[-*]\s*/, '').trim())
		.filter(Boolean)
		.map((line) => {
			const match = line.match(/^(.*?)\s*\(@?([A-Za-z0-9][A-Za-z0-9-]{0,38})\)\s*$/);
			return match ? { name: oneLine(match[1]), github: match[2] } : { name: oneLine(line) };
		});
	if (!speakers.length) errors.push('**Speakers** needs at least one name.');
	else if (speakers.length > 8) errors.push('**Speakers** lists more than 8 people.');
	else if (speakers.some((s) => s.name.length < 2 || s.name.length > 80)) errors.push('Each speaker name must be 2 to 80 characters.');
	else event.speakers = speakers;

	link('url', 'Event or registration link', true);
	text('summary', 'Summary', { max: 400 });
	link('recording', 'Recording link');
	link('slides', 'Slides link');
	if (issue) event.issue = issue;
	return { event, errors };
}

const slug = (text) =>
	text
		.toLowerCase()
		.normalize('NFKD')
		.replace(/[^\w\s-]/g, '')
		.trim()
		.replace(/[\s_-]+/g, '-')
		.slice(0, 50)
		.replace(/-+$/, '') || 'event';

/** The event as YAML: every value a JSON string or number, so nothing in it is read as YAML syntax. */
export function toYaml(event) {
	const order = ['title', 'event', 'start', 'end', 'time', 'format', 'attendance', 'city', 'country', 'language', 'speakers', 'url', 'recording', 'slides', 'summary', 'issue'];
	const lines = ['# Added from the event form. Edit freely; the schema is in website/src/content.config.ts.'];
	for (const key of order) {
		const value = event[key];
		if (value === undefined) continue;
		if (key === 'speakers') {
			lines.push('speakers:');
			for (const s of value) {
				lines.push(`  - name: ${JSON.stringify(s.name)}`);
				if (s.github) lines.push(`    github: ${JSON.stringify(s.github)}`);
			}
		} else if (key === 'start' || key === 'end' || key === 'issue') {
			lines.push(`${key}: ${value}`);
		} else {
			lines.push(`${key}: ${JSON.stringify(value)}`);
		}
	}
	return `${lines.join('\n')}\n`;
}

/** The file of the issue's event: the one it already has (an update), or a new name. */
export function fileFor(event, dir = eventsDir) {
	if (event.issue && existsSync(dir)) {
		const existing = readdirSync(dir).find((name) => /\.ya?ml$/.test(name) && new RegExp(`^issue: ${event.issue}$`, 'm').test(readFileSync(join(dir, name), 'utf8')));
		if (existing) return join(dir, existing);
	}
	let name = `${event.start}-${slug(`${event.event} ${event.title}`)}`;
	for (let n = 2; existsSync(join(dir, `${name}.yml`)); n++) name = `${event.start}-${slug(`${event.event} ${event.title}`)}-${n}`;
	return join(dir, `${name}.yml`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
	const issue = Number.parseInt(process.env.ISSUE_NUMBER ?? '', 10) || undefined;
	const { event, errors } = toEvent(readForm(process.env.ISSUE_BODY ?? ''), issue);
	if (errors.length) {
		const message = errors.map((e) => `- ${e}`).join('\n');
		console.error(message);
		if (process.env.EVENT_ERRORS_FILE) writeFileSync(process.env.EVENT_ERRORS_FILE, `${message}\n`);
		process.exit(1);
	}
	if (process.argv.includes('--check')) {
		console.log(toYaml(event));
	} else {
		const file = fileFor(event);
		writeFileSync(file, toYaml(event));
		console.log(`Wrote ${file}`);
		if (process.env.GITHUB_OUTPUT) {
			appendFileSync(process.env.GITHUB_OUTPUT, `file=${file}\ntitle=${event.title.replace(/[\r\n]/g, ' ')}\nevent=${event.event.replace(/[\r\n]/g, ' ')}\n`);
		}
	}
}
