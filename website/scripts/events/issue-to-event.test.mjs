import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileFor, readForm, toEvent, toYaml } from './issue-to-event.mjs';

const body = (overrides = {}) => {
	const answers = {
		'Session title': 'Testing Entra with Maester',
		'Event name': 'Nordic Virtual Summit 2027',
		Date: '2027-03-16',
		'Last day': '_No response_',
		'Time and time zone': '14:00 CET',
		Format: 'Talk',
		'Where can people join?': 'In person',
		City: 'Oslo',
		Country: 'Norway',
		Language: '_No response_',
		Speakers: 'Ada Lovelace (ada)\nGrace Hopper',
		'Event or registration link': 'https://example.com/session',
		Summary: 'What you learn.',
		'Recording link': '_No response_',
		'Slides link': '_No response_',
		Listing: '- [X] The speakers agree',
		...overrides,
	};
	return Object.entries(answers)
		.map(([k, v]) => `### ${k}\n\n${v}`)
		.join('\n\n');
};

test('reads a complete form', () => {
	const { event, errors } = toEvent(readForm(body()), 42);
	assert.deepEqual(errors, []);
	assert.equal(event.format, 'talk');
	assert.equal(event.attendance, 'in-person');
	assert.deepEqual(event.speakers, [{ name: 'Ada Lovelace', github: 'ada' }, { name: 'Grace Hopper' }]);
	assert.equal(event.end, undefined);
	assert.equal(event.language, undefined);
	assert.equal(event.issue, 42);
});

test('rejects bad dates, links and missing places', () => {
	const { errors } = toEvent(readForm(body({ Date: '16/03/2027', 'Event or registration link': 'javascript:alert(1)', City: '_No response_' })));
	assert.equal(errors.length, 3);
});

test('drops the place of an online event', () => {
	const { event, errors } = toEvent(readForm(body({ 'Where can people join?': 'Online' })));
	assert.deepEqual(errors, []);
	assert.equal(event.city, undefined);
});

test('writes values as JSON strings so YAML syntax in them stays text', () => {
	const { event } = toEvent(readForm(body({ 'Session title': 'Hack: {a: 1} # not a comment\nissue: 1' })));
	const yaml = toYaml(event);
	assert.match(yaml, /^title: "Hack: \{a: 1\} # not a comment issue: 1"$/m);
	assert.equal((yaml.match(/^issue:/gm) ?? []).length, 0);
});

test('updates the file an issue already made', () => {
	const dir = mkdtempSync(join(tmpdir(), 'events-'));
	writeFileSync(join(dir, '2027-01-01-old.yml'), 'title: "x"\nissue: 7\n');
	assert.equal(fileFor({ issue: 7, start: '2027-03-16', event: 'E', title: 'T' }, dir), join(dir, '2027-01-01-old.yml'));
	assert.equal(fileFor({ issue: 8, start: '2027-03-16', event: 'Nordic Summit', title: 'Maester' }, dir), join(dir, '2027-03-16-nordic-summit-maester.yml'));
});
