// Captures the views of public/demo/report.html as WebP images: the home page shows them on small screens (where
// the live report is too wide) and the how-it-works explainer animates them. Run after build-demo-report.mjs,
// with the dev or preview server serving the current build:  node scripts/capture-demo-report.mjs http://localhost:4321
// It also copies the dark captures into the how-it-works explainer.
import { chromium } from 'playwright';
import sharp from 'sharp';
import { copyFileSync } from 'node:fs';

const base = process.argv[2] ?? 'http://localhost:4321';
export const views = [
	{ name: 'overview', hash: '/' },
	{ name: 'plan', hash: '/plan' },
	{ name: 'test', hash: '/CIS.M365.1.1.1' },
	{ name: 'framework', hash: '/framework/cis-m365' },
	{ name: 'attack', hash: '/attack' },
	{ name: 'zta', hash: '/pack/maester.zero-trust-assessment' },
];

const browser = await chromium.launch();
for (const theme of ['light', 'dark']) {
	const page = await browser.newPage({ viewport: { width: 1600, height: 1000 }, deviceScaleFactor: 1.5, colorScheme: theme });
	for (const view of views) {
		await page.goto(`${base}/demo/report#${view.hash}`, { waitUntil: 'networkidle' });
		await page.waitForTimeout(800);
		const png = await page.screenshot();
		await sharp(png).webp({ quality: 80 }).toFile(new URL(`../public/demo/views/${view.name}-${theme}.webp`, import.meta.url).pathname);
	}
	await page.close();
}
await browser.close();
for (const view of views) copyFileSync(new URL(`../public/demo/views/${view.name}-dark.webp`, import.meta.url), new URL(`../public/explainers/how-it-works/img/${view.name}.webp`, import.meta.url));
console.log('Captured', views.length * 2, 'views.');
