// Renders each page's Open Graph image after `astro build` (see src/lib/og.mjs). Reads the card each page wrote into
// <meta name="maester:og">, removes that tag, and writes dist/og/<page>.jpg. A rendered card is kept in
// website/.cache/og under its hash, so a build renders only the cards that changed; the build-website workflow keeps
// that folder between runs. Cards no page uses any more are deleted from it.
import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import satori from 'satori';
import sharp from 'sharp';
import { CARD_HEIGHT, CARD_WIDTH, cardHash, defaultCard } from '../src/lib/og.mjs';

const websiteRoot = fileURLToPath(new URL('..', import.meta.url));
const dist = join(websiteRoot, 'dist');
const cache = join(websiteRoot, '.cache', 'og');
mkdirSync(cache, { recursive: true });

const font = (file) => readFileSync(join(websiteRoot, 'node_modules', file));
const fonts = [
	{ name: 'Inter', data: font('@fontsource/inter/files/inter-latin-400-normal.woff'), weight: 400, style: 'normal' },
	{ name: 'Inter', data: font('@fontsource/inter/files/inter-latin-600-normal.woff'), weight: 600, style: 'normal' },
	{ name: 'Inter', data: font('@fontsource/inter/files/inter-latin-700-normal.woff'), weight: 700, style: 'normal' },
	{ name: 'Geist Mono', data: font('@fontsource/geist-mono/files/geist-mono-latin-500-normal.woff'), weight: 500, style: 'normal' },
];
const mark = `data:image/png;base64,${(await sharp(join(websiteRoot, 'src/assets/maester-mark.svg')).resize(112, 112).png().toBuffer()).toString('base64')}`;

const ink = { white: '#fafafa', gray: '#a1a1aa', dim: '#71717a', line: '#3f3f46', ember: '#ff6b6f', bg: '#09090b' };
const severityColor = { Critical: '#f87171', High: '#fb923c', Medium: '#fbbf24', Low: '#60a5fa', Info: '#a1a1aa' };

// satori takes a React-like tree; this keeps the card readable without JSX.
const h = (type, style, ...children) => ({ type, props: { style: { display: 'flex', ...style }, children: children.flat().filter((c) => c !== null && c !== undefined && c !== false) } });

function titleSize(title, code) {
	const length = title.length * (code ? 1.15 : 1);
	return length <= 32 ? 76 : length <= 60 ? 64 : length <= 90 ? 54 : 46;
}

function cardTree(card) {
	const chip = (text, color) =>
		h('div', { alignItems: 'center', gap: 10, padding: '8px 18px', border: `2px solid ${ink.line}`, borderRadius: 999, fontSize: 24, color: ink.gray }, color ? h('div', { width: 12, height: 12, borderRadius: 999, background: color }) : null, text);
	const facts = card.id || card.severity || card.chips?.length
		? h(
				'div',
				{ alignItems: 'center', gap: 14, marginBottom: 28 },
				card.id ? h('div', { fontFamily: 'Geist Mono', fontSize: 30, color: ink.ember, marginRight: 6 }, card.id) : null,
				card.severity ? chip(card.severity, severityColor[card.severity] ?? ink.gray) : null,
				(card.chips ?? []).map((text) => chip(text)),
			)
		: null;
	return h(
		'div',
		{
			position: 'absolute',
			top: 0,
			left: 0,
			width: CARD_WIDTH,
			height: CARD_HEIGHT,
			flexDirection: 'column',
			padding: '64px 72px',
			boxSizing: 'border-box',
			background: ink.bg,
			backgroundImage: 'radial-gradient(circle at 100% 0%, rgba(210, 44, 49, 0.38) 0%, rgba(210, 44, 49, 0.08) 38%, rgba(9, 9, 11, 0) 62%)',
			fontFamily: 'Inter',
			color: ink.white,
		},
		h(
			'div',
			{ alignItems: 'center', justifyContent: 'space-between' },
			h('div', { alignItems: 'center', gap: 16 }, { type: 'img', props: { src: mark, width: 56, height: 56 } }, h('div', { fontSize: 36, fontWeight: 700, letterSpacing: '-0.02em' }, 'Maester')),
			card.label ? h('div', { fontFamily: 'Geist Mono', fontSize: 22, letterSpacing: '0.08em', textTransform: 'uppercase', color: ink.gray, padding: '10px 20px', border: `2px solid ${ink.line}`, borderRadius: 999 }, card.label) : null,
		),
		h(
			'div',
			{ flexDirection: 'column', marginTop: 'auto', marginBottom: 'auto', paddingTop: 24 },
			facts,
			h(
				'div',
				{
					display: 'block',
					fontFamily: card.code ? 'Geist Mono' : 'Inter',
					fontWeight: card.code ? 500 : 700,
					fontSize: titleSize(card.title, card.code),
					lineHeight: 1.1,
					letterSpacing: card.code ? '-0.01em' : '-0.03em',
					lineClamp: 3,
				},
				card.title,
			),
			card.description ? h('div', { display: 'block', marginTop: 24, fontSize: 28, lineHeight: 1.4, color: ink.gray, lineClamp: 2 }, card.description) : null,
		),
		h('div', { alignItems: 'center', justifyContent: 'space-between', fontFamily: 'Geist Mono', fontSize: 24, color: ink.dim }, h('div', {}, 'maester.dev'), h('div', { width: 120, height: 6, borderRadius: 999, background: 'linear-gradient(90deg, #d22c31, #ff6b6f, #fbbf24)' })),
	);
}

async function render(card, file) {
	const hash = cardHash(card);
	const cached = join(cache, `${hash}.jpg`);
	if (!existsSync(cached)) {
		const svg = await satori(cardTree(card), { width: CARD_WIDTH, height: CARD_HEIGHT, fonts });
		// JPEG, not a 256-colour PNG: a palette turns the glow into bands, and a full-colour PNG is five times larger.
		writeFileSync(cached, await sharp(Buffer.from(svg)).jpeg({ quality: 86, mozjpeg: true, chromaSubsampling: '4:4:4' }).toBuffer());
		rendered++;
	}
	mkdirSync(dirname(file), { recursive: true });
	copyFileSync(cached, file);
}

const decode = (text) => text.replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&#x27;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
const tag = /<meta name="maester:og" content="([^"]*)"\s*\/?>/;

function* pages(dir) {
	for (const entry of readdirSync(dir, { withFileTypes: true })) {
		const path = join(dir, entry.name);
		if (entry.isDirectory()) yield* pages(path);
		else if (entry.name.endsWith('.html')) yield path;
	}
}

let rendered = 0;
const cards = new Map([[defaultCard.path, defaultCard]]);
for (const page of pages(dist)) {
	const html = readFileSync(page, 'utf8');
	const match = html.match(tag);
	if (!match) continue;
	const card = JSON.parse(decode(match[1]));
	cards.set(card.path, card);
	writeFileSync(page, html.replace(tag, ''));
}

const queue = [...cards.values()];
const workers = Array.from({ length: 8 }, async () => {
	for (let card = queue.shift(); card; card = queue.shift()) await render(card, join(dist, 'og', `${card.path}.jpg`));
});
await Promise.all(workers);
const used = new Set([...cards.values()].map((card) => `${cardHash(card)}.jpg`));
for (const file of readdirSync(cache)) if (!used.has(file)) rmSync(join(cache, file));
console.log(`Open Graph images: ${cards.size} cards, ${rendered} rendered, ${cards.size - rendered} from the cache.`);

// Fails the build when a page links an image this script did not write (a page whose layout forgot its card).
const missing = [];
for (const page of pages(dist)) {
	const image = readFileSync(page, 'utf8').match(/<meta property="og:image" content="https:\/\/maester\.dev\/og\/([^"?]+)/);
	if (image && !existsSync(join(dist, 'og', decodeURIComponent(image[1])))) missing.push(`${page.slice(dist.length)} → /og/${image[1]}`);
}
if (missing.length > 0) {
	console.error(`Open Graph images: ${missing.length} pages link an image that was not rendered:\n${missing.slice(0, 20).join('\n')}`);
	process.exit(1);
}
