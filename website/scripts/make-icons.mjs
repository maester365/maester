// Writes the site's icons from the Maester mark (src/assets/maester-mark.svg): favicon.ico (16, 32 and 48 px),
// icon-192.png and icon-512.png for the web manifest, and apple-touch-icon.png on the site's dark background.
// Run it again only when the mark changes: node scripts/make-icons.mjs
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const at = (path) => fileURLToPath(new URL(`../${path}`, import.meta.url));
const mark = at('src/assets/maester-mark.svg');
const png = (size, pad = 0, background) =>
	sharp(mark)
		.resize(size - pad * 2, size - pad * 2)
		.extend({ top: pad, bottom: pad, left: pad, right: pad, background: background ?? { r: 0, g: 0, b: 0, alpha: 0 } })
		.flatten(background ? { background } : undefined)
		.png({ compressionLevel: 9 })
		.toBuffer();

// An ICO file whose entries are PNG images, which every current browser reads.
const sizes = [16, 32, 48];
const images = await Promise.all(sizes.map((size) => png(size)));
const header = Buffer.alloc(6 + sizes.length * 16);
header.writeUInt16LE(0, 0);
header.writeUInt16LE(1, 2);
header.writeUInt16LE(sizes.length, 4);
let offset = header.length;
sizes.forEach((size, i) => {
	const entry = 6 + i * 16;
	header.writeUInt8(size, entry);
	header.writeUInt8(size, entry + 1);
	header.writeUInt16LE(1, entry + 4);
	header.writeUInt16LE(32, entry + 6);
	header.writeUInt32LE(images[i].length, entry + 8);
	header.writeUInt32LE(offset, entry + 12);
	offset += images[i].length;
});
writeFileSync(at('public/favicon.ico'), Buffer.concat([header, ...images]));
writeFileSync(at('public/icon-192.png'), await png(192, 16));
writeFileSync(at('public/icon-512.png'), await png(512, 40));
writeFileSync(at('public/apple-touch-icon.png'), await png(180, 24, '#09090b'));
