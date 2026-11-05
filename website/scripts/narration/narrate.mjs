// Makes the voice-over of an explainer with Kokoro (https://huggingface.co/hexgrad/Kokoro-82M, Apache 2.0),
// from the chapters in src/data/explainers.json. It records every chapter, with a pause between them (music.mjs then
// mixes it with the music into public/explainers/<slug>/audio/mix.mp3, which the composition plays), and the start time of each chapter back into explainers.json and into
// public/explainers/<slug>/timings.js, which the composition's timeline reads.
//
// Usage (in website/scripts/narration, after npm install):  node narrate.mjs how-it-works
// The first run downloads the model (about 330 MB) from Hugging Face into the npm cache.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { Mp3Encoder } from '@breezystack/lamejs';
import { KokoroTTS } from 'kokoro-js';

const slug = process.argv[2];
const dataPath = new URL('../../src/data/explainers.json', import.meta.url);
const explainers = JSON.parse(readFileSync(dataPath, 'utf8'));
const explainer = explainers[slug];
if (!explainer) throw new Error(`No explainer "${slug}" in src/data/explainers.json.`);
const outDir = new URL(`../../public/explainers/${slug}/`, import.meta.url);
mkdirSync(new URL('audio/', outDir), { recursive: true });

const lead = 0.3; // seconds before the first line: the explainer starts talking as soon as it plays
const gap = 0.9; // seconds between chapters
const tts = await KokoroTTS.from_pretrained('onnx-community/Kokoro-82M-v1.0-ONNX', { dtype: 'fp32', device: 'cpu' });

// How names and flags are spoken, for chapters without a `say` line of their own.
const spoken = (text) =>
	text
		.replace(/\bInvoke-Maester\b/g, 'Invoke Mayster')
		.replace(/\bMaester\b/g, 'Mayster')
		.replace(/Microsoft 365/g, 'Microsoft three sixty-five')
		.replace(/-DryRun/g, 'dry run')
		.replace(/\bJUnit\b/g, 'J Unit')
		.replace(/\bServiceNotConnected\b/g, 'Service Not Connected');

// An explainer whose animation has fixed chapter times (`"timing": "fixed"`) keeps them: each line starts just after
// its chapter does. Otherwise the chapters follow the voice-over, one after another.
const fixed = explainer.timing === 'fixed';
let sampleRate = 24000;
const parts = [];
let t = lead;
for (const [i, chapter] of explainer.chapters.entries()) {
	const audio = await tts.generate(chapter.say ?? spoken(chapter.text), { voice: explainer.voice ?? 'af_heart', speed: 1 });
	sampleRate = audio.sampling_rate;
	// A few milliseconds of fade at each end, so a line never starts or stops with a click.
	const fade = Math.floor(0.008 * sampleRate);
	for (let k = 0; k < fade && k < audio.audio.length; k++) {
		audio.audio[k] *= k / fade;
		audio.audio[audio.audio.length - 1 - k] *= k / fade;
	}
	const seconds = audio.audio.length / sampleRate;
	if (fixed) {
		t = chapter.t + lead;
		const next = explainer.chapters[i + 1]?.t ?? explainer.duration;
		if (t + seconds > next) console.warn(`  ${chapter.id} runs ${(t + seconds - next).toFixed(1)}s into the next chapter: shorten its text.`);
	} else {
		chapter.t = Math.round(t * 10) / 10;
	}
	chapter.length = Math.round(seconds * 10) / 10;
	parts.push({ at: t, samples: audio.audio });
	if (!fixed) t += seconds + gap;
	console.log(`${chapter.id ?? String(i).padEnd(12)} ${t.toFixed(1)}s  ${chapter.length.toFixed(1)}s`);
}
if (!fixed) explainer.duration = Math.ceil(t + 2.5); // room for the closing card

// One mono track with every chapter at its start time.
const track = new Float32Array(Math.ceil(explainer.duration * sampleRate));
for (const part of parts) track.set(part.samples, Math.round(part.at * sampleRate));
const pcm = new Int16Array(track.length);
for (let i = 0; i < track.length; i++) pcm[i] = Math.max(-1, Math.min(1, track[i])) * 0x7fff;
const encoder = new Mp3Encoder(1, sampleRate, 64);
const chunks = [];
for (let i = 0; i < pcm.length; i += 1152) chunks.push(encoder.encodeBuffer(pcm.subarray(i, i + 1152)));
chunks.push(encoder.flush());
mkdirSync(new URL('.cache/', import.meta.url), { recursive: true });
writeFileSync(new URL(`.cache/${slug}-voice.mp3`, import.meta.url), Buffer.concat(chunks.map((c) => Buffer.from(c.buffer, c.byteOffset, c.byteLength))));
// The raw track, for music.mjs to mix the music under.
mkdirSync(new URL('.cache/', import.meta.url), { recursive: true });
writeFileSync(new URL(`.cache/${slug}-voice.f32`, import.meta.url), Buffer.from(track.buffer));
writeFileSync(new URL(`.cache/${slug}-voice.json`, import.meta.url), JSON.stringify({ sampleRate }));

writeFileSync(dataPath, `${JSON.stringify(explainers, null, 2)}\n`);
writeFileSync(
	new URL('timings.js', outDir),
	`// Written by scripts/narration/narrate.mjs from the voice-over. Do not edit.\nwindow.__chapters = ${JSON.stringify(
		Object.fromEntries(explainer.chapters.map((c, i) => [c.id ?? String(i), { t: c.t, length: c.length }])),
	)};\nwindow.__duration = ${explainer.duration};\n`,
);
console.log(`Voice-over: ${explainer.duration}s, ${explainer.chapters.length} chapters.`);
