// Captures the views of public/demo/report.html as WebP images: the home page shows them on small screens (where
// the live report is too wide) and the how-it-works explainer animates them. Run after build-demo-report.mjs,
// with the dev or preview server serving the current build:  node scripts/capture-demo-report.mjs http://localhost:4321
// It also refreshes the dark captures the how-it-works explainer already uses.
// To capture only some views, name them:  node scripts/capture-demo-report.mjs http://localhost:4321 changes,run
// CAPTURE_CHANNEL=chrome uses the Chrome that is installed instead of Playwright's own browser.
import { chromium } from 'playwright';
import sharp from 'sharp';
import { copyFileSync, existsSync, rmSync } from 'node:fs';

const base = process.argv[2] ?? 'http://localhost:4321';
// Each view is a route of the report; `scroll` names an element to bring to the top first, and `click` a button to
// press, for a view that has no route of its own (the plan's swimlanes sit below its summary).
export const views = [
	{ name: 'overview', hash: '/' },
	{ name: 'plan', hash: '/plan' },
	{ name: 'test', hash: '/CIS.M365.1.1.1' },
	{ name: 'framework', hash: '/framework/cis-m365' },
	{ name: 'attack', hash: '/attack' },
	{ name: 'zt-board', hash: '/pack/zta/plan/identity', scroll: '.mt-zt-boardsec' },
	{ name: 'zt-table', hash: '/pack/zta/plan/identity#table', scroll: '.mt-zt-boardsec' },
	{ name: 'zta', hash: '/pack/zta' },
	// Microsoft's own report, with its Sankey chart, when the demo carries it (build-demo-report.mjs --attach).
	{ name: 'zt-report', hash: '/reports/zero-trust-assessment', optional: true },
	// For the report guide (docs/report) only; the home page does not show these.
	{ name: 'changes', hash: '/changes' },
	{ name: 'tests', hash: '/tests' },
	{ name: 'product', hash: '/product/entra' },
	{ name: 'affected-objects', hash: '/affected-objects' },
	{ name: 'run', hash: '/run' },
	{ name: 'zt-plan', hash: '/pack/zta/plan/identity' },
	{ name: 'zt-task', hash: '/pack/zta/plan/identity', scroll: '.mt-zt-boardsec', click: '.mt-zt-card.s-partial' },
];
const only = process.argv[3]?.split(',');
const wanted = only ? views.filter((v) => only.includes(v.name)) : views;

const browser = await chromium.launch({ channel: process.env.CAPTURE_CHANNEL || undefined });
for (const theme of ['light', 'dark']) {
	const page = await browser.newPage({ viewport: { width: 1600, height: 1000 }, deviceScaleFactor: 1.5, colorScheme: theme });
	for (const view of wanted) {
		await page.goto(`${base}/demo/report.html#${view.hash}`, { waitUntil: 'networkidle' });
		// Going from one view to another of the same file only changes the hash: reload, so every capture starts clean.
		await page.reload({ waitUntil: 'networkidle' });
		await page.waitForTimeout(1200);
		if (view.optional && !(await page.locator('iframe').count())) {
			// Remove an earlier capture, so the home page doesn't show a view the demo no longer has.
			rmSync(new URL(`../public/demo/views/${view.name}-${theme}.webp`, import.meta.url).pathname, { force: true });
			console.log(`Skipped ${view.name}: the demo report has no such page.`);
			continue;
		}
		if (view.scroll) {
			await page.evaluate((selector) => {
				const el = document.querySelector(selector);
				if (!el) return;
				el.scrollIntoView({ block: 'start' });
				window.scrollBy(0, -24);
			}, view.scroll);
			await page.waitForTimeout(400);
		}
		if (view.click) {
			await page.locator(view.click).first().click();
			await page.waitForTimeout(600);
		}
		const png = await page.screenshot();
		await sharp(png).webp({ quality: 80 }).toFile(new URL(`../public/demo/views/${view.name}-${theme}.webp`, import.meta.url).pathname);
	}
	await page.close();
}
await browser.close();
for (const view of views.filter((v) => existsSync(new URL(`../public/demo/views/${v.name}-dark.webp`, import.meta.url)) && existsSync(new URL(`../public/explainers/how-it-works/img/${v.name}.webp`, import.meta.url)))) copyFileSync(new URL(`../public/demo/views/${view.name}-dark.webp`, import.meta.url), new URL(`../public/explainers/how-it-works/img/${view.name}.webp`, import.meta.url));
console.log('Captured', wanted.length * 2, 'views.');
