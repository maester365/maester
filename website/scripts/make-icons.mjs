// Writes the site's icons from the Maester mark (src/assets/maester-mark.svg): icon-192.png and icon-512.png for the
// web manifest, and apple-touch-icon.png on the site's dark background (iOS fills a transparent icon with black).
// public/favicon.ico is the old site's favicon (public/img/favicon.ico), kept as it is.
// Run it again only when the mark changes: node scripts/make-icons.mjs
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const at = (path) => fileURLToPath(new URL(`../${path}`, import.meta.url));
const mark = at('src/assets/maester-mark.svg');
// Transparent unless a background is given. sharp pads (extend) after it flattens, so the padding gets the
// background too.
async function write(file, size, pad, background) {
	let image = sharp(mark)
		.resize(size - pad * 2, size - pad * 2)
		.extend({ top: pad, bottom: pad, left: pad, right: pad, background: background ?? { r: 0, g: 0, b: 0, alpha: 0 } });
	if (background) image = image.flatten({ background });
	writeFileSync(at(file), await image.png({ compressionLevel: 9 }).toBuffer());
}

await write('public/icon-192.png', 192, 16);
await write('public/icon-512.png', 512, 40);
await write('public/apple-touch-icon.png', 180, 24, '#09090b');
