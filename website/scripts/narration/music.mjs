// Composes the music bed of an explainer: an original, synthesised track (no samples, no third-party audio), so
// there is nothing to license. A warm pad on I–V–vi–IV in D major, an arpeggio that builds, a soft bass, and a lift
// into the closing card. Writes public/explainers/<slug>/audio/mix.mp3, as long as the voice-over:
// the voice-over over the music, which ducks while someone is speaking. Run narrate.mjs first.
//
// Usage (in website/scripts/narration):  node music.mjs how-it-works
import { readFileSync, writeFileSync } from 'node:fs';
import { Mp3Encoder } from '@breezystack/lamejs';

const slug = process.argv[2];
const explainer = JSON.parse(readFileSync(new URL('../../src/data/explainers.json', import.meta.url), 'utf8'))[slug];
if (!explainer?.duration) throw new Error(`Run narrate.mjs ${slug} first: the music follows the voice-over's length.`);

const rate = 44100;
const duration = explainer.duration;
const length = duration * rate;
const left = new Float32Array(length);
const right = new Float32Array(length);

const bpm = 88;
const beat = 60 / bpm;
const bar = beat * 4;
const midi = (n) => 440 * 2 ** ((n - 69) / 12);
// D, A, Bm, G: each chord as MIDI notes (pad voicing), root for the bass.
const chords = [
	{ notes: [62, 66, 69, 74], root: 38 },
	{ notes: [61, 64, 69, 73], root: 45 },
	{ notes: [62, 66, 71, 74], root: 47 },
	{ notes: [62, 67, 71, 74], root: 43 },
];
const chordAt = (t) => chords[Math.floor(t / bar) % chords.length];

// Wavetables: a soft pad (few harmonics, falling off fast) and a bell-like pluck.
const size = 4096;
const table = (harmonics) => {
	const w = new Float32Array(size);
	for (let i = 0; i < size; i++) for (const [h, a] of harmonics) w[i] += a * Math.sin((2 * Math.PI * h * i) / size);
	const peak = Math.max(...w.map(Math.abs));
	return w.map((v) => v / peak);
};
const padWave = table([[1, 1], [2, 0.32], [3, 0.16], [4, 0.07], [5, 0.04]]);
const pluckWave = table([[1, 1], [2, 0.18], [3, 0.08], [6, 0.03]]);
// Read between two table entries, not the nearest one: rounding to an entry adds a gritty noise.
const read = (wave, phase) => {
	const x = phase * size;
	const i = Math.floor(x);
	const a = wave[i & (size - 1)];
	return a + (wave[(i + 1) & (size - 1)] - a) * (x - i);
};

// Overall shape: in within half a second (the voice starts almost at once), build under the console section, lift at the end, fade out.
const shape = (t) => {
	const fadeIn = Math.min(1, t / 0.5);
	const fadeOut = Math.min(1, (duration - t) / 4);
	const build = 0.55 + 0.45 * Math.min(1, Math.max(0, (t - 20) / 30));
	const lift = t > duration - 15 ? 1.15 : 1;
	return fadeIn * fadeOut * build * lift;
};

// Pad: every chord note, three slightly detuned voices, swelling in each bar. Each chord crossfades into the next
// over the last half second of its bar: switching notes in one step would click at every bar line.
const detune = [-0.06, 0, 0.07];
const crossfade = 0.5;
const padVoice = (notes, t) => {
	let l = 0;
	let r = 0;
	for (const [n, note] of notes.entries()) {
		for (const [d, cents] of detune.entries()) {
			const v = read(padWave, (t * midi(note + cents)) % 1);
			const pan = (n + d) % 2 === 0 ? 0.62 : 0.38;
			l += v * pan;
			r += v * (1 - pan);
		}
	}
	return [l, r];
};
for (let i = 0; i < length; i++) {
	const t = i / rate;
	const barIndex = Math.floor(t / bar);
	const inBar = t - barIndex * bar;
	const env = Math.min(1, inBar / 1.2) * (inBar > bar - 0.6 ? (bar - inBar) / 0.6 : 1) * 0.6 + 0.4;
	let [l, r] = padVoice(chords[barIndex % chords.length].notes, t);
	if (inBar > bar - crossfade) {
		const w = 0.5 - 0.5 * Math.cos((Math.PI * (inBar - (bar - crossfade))) / crossfade);
		const [nl, nr] = padVoice(chords[(barIndex + 1) % chords.length].notes, t);
		l = l * (1 - w) + nl * w;
		r = r * (1 - w) + nr * w;
	}
	const gain = 0.022 * env * shape(t);
	left[i] += l * gain;
	right[i] += r * gain;
}

// Arpeggio: eighth notes over the chord, an octave up, from 6 s; louder as the piece builds.
const eighth = beat / 2;
for (let step = Math.ceil(6 / eighth); step * eighth < duration - 3; step++) {
	const start = step * eighth;
	const { notes } = chordAt(start);
	const pattern = [0, 1, 2, 3, 2, 1, 2, 3];
	const note = notes[pattern[step % pattern.length]] + 12;
	const f = midi(note);
	const pan = step % 2 ? 0.7 : 0.3;
	const level = 0.09 * shape(start) * (start > 35 ? 1 : 0.65);
	const end = Math.min(length, Math.floor((start + 1.6) * rate));
	for (let i = Math.floor(start * rate); i < end; i++) {
		const dt = i / rate - start;
		const release = Math.min(1, (1.6 - dt) / 0.05);
		const v = read(pluckWave, (dt * f) % 1) * Math.exp(-dt * 3.2) * Math.min(1, dt / 0.004) * release * level;
		left[i] += v * pan;
		right[i] += v * (1 - pan);
	}
}

// Bass: a soft root on beats one and three, from 20 s.
for (let b = Math.ceil(20 / beat); b * beat < duration - 3; b++) {
	if (b % 2) continue;
	const start = b * beat;
	const f = midi(chordAt(start).root);
	const hold = beat * 1.8;
	const end = Math.min(length, Math.floor((start + hold) * rate));
	for (let i = Math.floor(start * rate); i < end; i++) {
		const dt = i / rate - start;
		// Fade out over the last 80 ms: a note cut off mid-cycle clicks.
		const release = Math.min(1, (hold - dt) / 0.08);
		const v = Math.sin(2 * Math.PI * f * dt) * Math.exp(-dt * 1.4) * Math.min(1, dt / 0.01) * release * 0.16 * shape(start);
		left[i] += v;
		right[i] += v;
	}
}

// Room: a few cross-fed delays for space.
const taps = [
	[0.029, 0.32],
	[0.047, 0.26],
	[0.083, 0.2],
	[0.131, 0.14],
	[0.211, 0.1],
];
const wetL = new Float32Array(length);
const wetR = new Float32Array(length);
for (const [delay, g] of taps) {
	const d = Math.floor(delay * rate);
	for (let i = d; i < length; i++) {
		wetL[i] += right[i - d] * g;
		wetR[i] += left[i - d] * g;
	}
}
let peak = 0;
for (let i = 0; i < length; i++) {
	left[i] += wetL[i];
	right[i] += wetR[i];
	peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]));
}

const encode = (l16, r16) => {
	const encoder = new Mp3Encoder(2, rate, 192);
	const chunks = [];
	for (let i = 0; i < l16.length; i += 1152) chunks.push(encoder.encodeBuffer(l16.subarray(i, i + 1152), r16.subarray(i, i + 1152)));
	chunks.push(encoder.flush());
	return Buffer.concat(chunks.map((c) => Buffer.from(c.buffer, c.byteOffset, c.byteLength)));
};
const toPcm = (x, scale) => {
	const p = new Int16Array(x.length);
	for (let i = 0; i < x.length; i++) p[i] = Math.max(-1, Math.min(1, x[i] * scale)) * 0x7fff;
	return p;
};
const audioDir = new URL(`../../public/explainers/${slug}/audio/`, import.meta.url);
writeFileSync(new URL(`.cache/${slug}-music.mp3`, import.meta.url), encode(toPcm(left, 0.89 / peak), toPcm(right, 0.89 / peak)));

// The mix: the voice-over (resampled to 44.1 kHz) over the music, which sits at -14 dB and dips a further 8 dB while
// the voice is speaking, with smooth attack and release.
const meta = JSON.parse(readFileSync(new URL(`.cache/${slug}-voice.json`, import.meta.url), 'utf8'));
const raw = readFileSync(new URL(`.cache/${slug}-voice.f32`, import.meta.url));
const voiceIn = new Float32Array(raw.buffer, raw.byteOffset, raw.byteLength / 4);
// Resampled with a windowed sinc: drawing straight lines between samples leaves mirror images of the voice above
// 12 kHz, which sound like a fizz or crackle on every "s" and "t".
const voice = new Float32Array(length);
const ratio = meta.sampleRate / rate;
const half = 24; // input samples either side
const cutoff = 0.95; // just under the voice's own top frequency
for (let i = 0; i < length; i++) {
	const x = i * ratio;
	const j = Math.floor(x);
	let sum = 0;
	for (let k = j - half + 1; k <= j + half; k++) {
		if (k < 0 || k >= voiceIn.length) continue;
		const d = x - k;
		const sinc = d === 0 ? 1 : Math.sin(Math.PI * cutoff * d) / (Math.PI * cutoff * d);
		const blackman = 0.42 + 0.5 * Math.cos((Math.PI * d) / half) + 0.08 * Math.cos((2 * Math.PI * d) / half);
		sum += voiceIn[k] * cutoff * sinc * blackman;
	}
	voice[i] = sum;
}
const bed = 10 ** (-14 / 20) * (0.89 / peak);
const duck = 10 ** (-8 / 20);
const window_ = Math.floor(0.05 * rate);
let env = 0;
let gain = 1;
const mixL = new Float32Array(length);
const mixR = new Float32Array(length);
for (let i = 0; i < length; i++) {
	env = Math.max(Math.abs(voice[i]), env * Math.exp(-1 / window_));
	const target = env > 0.02 ? duck : 1;
	gain += (target - gain) * (target < gain ? 0.0008 : 0.00008);
	const v = voice[i] * 0.95;
	mixL[i] = v + left[i] * bed * gain;
	mixR[i] = v + right[i] * bed * gain;
}
writeFileSync(new URL('mix.mp3', audioDir), encode(toPcm(mixL, 1), toPcm(mixR, 1)));
console.log(`Music and mix: ${duration}s.`);
