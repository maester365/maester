// Builds public/demo/report.html: the real Maester HTML report filled with sample results, for the home page and
// the "Open the demo report" link. Run it when the report template or its sample data changes.
//
// Usage (from website/):
//   node scripts/build-demo-report.mjs <report template .html> <sample results .ts or .json>
//
// The template is the built report (report/dist/index.html, or powershell/assets/ReportTemplate.html once it is
// released). The sample is report/src/lib/testResults.ts, the data the report's own dev server uses. The sample
// comes from a real demo tenant, so its names, domains and IDs are replaced with Contoso before it is published.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const [templatePath, dataPath] = process.argv.slice(2);
if (!templatePath || !dataPath) {
	console.error('Usage: node scripts/build-demo-report.mjs <report template .html> <sample results .ts|.json>');
	process.exit(1);
}
const out = new URL('../public/demo/report.html', import.meta.url);

function loadResults(path) {
	const text = readFileSync(path, 'utf8');
	if (path.endsWith('.json')) return JSON.parse(text);
	// The .ts sample is `export const testResults = { ... }` followed by type exports.
	const start = text.indexOf('export const testResults =');
	const objectStart = text.indexOf('{', start);
	const objectEnd = text.search(/\n}\s*;?\s*\n/) + 2;
	return new Function(`return (${text.slice(objectStart, objectEnd)})`)();
}

// Fictional names Microsoft uses for demos, in place of the demo tenant's.
const replacements = [
	[/\/Users\/merill\/GitHub\/maester\//gi, '/home/runner/work/maester/'],
	[/merillf_gmail\.com/gi, 'adele_outlook.com'],
	[/merill_merill\.net/gi, 'megan_fabrikam.com'],
	[/elapora-/gi, 'contoso-'],
	[/pora\.onmicrosoft\.com/gi, 'contoso.onmicrosoft.com'],
	[/elapora\.com/gi, 'contoso.com'],
	[/Pora Inc\./g, 'Contoso'],
	[/\bPora\b/g, 'Contoso'],
	[/\bpora\b/g, 'contoso'],
	// People in the demo tenant, as Microsoft's demo personas.
	[/Aleksandar Nikolic/g, 'Alex Wilber'],
	[/Joshua Fernando/g, 'Lee Gu'],
	[/Bagul Atayewa/g, 'Nestor Wilke'],
	[/Madura Sonnadara/g, 'Megan Bowen'],
	[/Ann Quinzon/g, 'Isaiah Langer'],
	[/Damien Bowden/g, 'Diego Siciliani'],
	[/Gael Colas/g, 'Lidia Holloway'],
	[/Ravi Kalwani/g, 'Lynne Robbins'],
	[/Tyler Chan/g, 'Miriam Graham'],
	[/Test-Madura-/g, 'Test-Megan-'],
	[/Madura- /g, 'Megan - '],
	[/Varsha Mane/g, 'Johanna Lorenz'],
	[/Bob Leaf/g, 'Joni Sherman'],
	[/Tyler Chan/g, 'Miriam Graham'],
	[/Test-Madura-/g, 'Test-Megan-'],
	[/Madura- /g, 'Megan - '],
	[/\bchukka\.p\b/g, 'pradeep.g'],
	[/\bKomal\.p\b/g, 'patti.f'],
	[/\bmanoj\.p\b/g, 'christie.c'],
	[/\bperennial_ash\b/g, 'henrietta.m'],
	[/Merill Fernando/g, 'Adele Vance'],
	[/\bMerill\b/g, 'Adele'],
	[/\bmerill\b/g, 'adele'],
];

const results = loadResults(dataPath);
delete results.TenantLogos;
const demoTenantId = '6f1a2b3c-4d5e-4f60-8a7b-9c0d1e2f3a4b';
let json = JSON.stringify(results).replaceAll(results.TenantId, demoTenantId);
for (const [pattern, value] of replacements) json = json.replace(pattern, value);
// Every personal address becomes a demo persona; addresses that name a role or a test object stay.
const personas = ['alex.wilber', 'lee.gu', 'nestor.wilke', 'megan.bowen', 'isaiah.langer', 'diego.siciliani', 'lidia.holloway', 'lynne.robbins', 'miriam.graham', 'johanna.lorenz', 'joni.sherman', 'pradeep.gupta', 'patti.fernandez', 'christie.cline', 'grady.archie', 'henrietta.mueller'];
const roleAddress = /^(admin|emergency|unlicensed|nomailenabled|nousagelocation|usernonick|new|breakglass\d*|emergencyaccessgroup|aitest\d+|agentuser\d+|agent\.\w+|sync_dc\d*_\w+)$/i;
const addresses = new Map();
json = json.replace(/\b([A-Za-z0-9._#-]+)@(contoso(?:\.mail)?(?:\.onmicrosoft)?\.com)\b/g, (match, local, domain) => {
	if (roleAddress.test(local)) return match;
	const key = local.toLowerCase();
	if (!addresses.has(key)) addresses.set(key, personas[addresses.size % personas.length] + (addresses.size >= personas.length ? String(Math.floor(addresses.size / personas.length) + 1) : ''));
	return `${addresses.get(key)}@${domain}`;
});
const leftover = json.match(/elapora|pora\.onmicrosoft|merill|\bpora\b|kalwani|sonnadara|atayewa|quinzon|nikolic|perennial|varsha|tyler|shobalak|joshua|madura/i) ?? json.match(new RegExp(results.TenantId, 'i'));
if (leftover) throw new Error(`The sample still names the demo tenant: ${leftover[0]}`);

const template = readFileSync(templatePath, 'utf8');
const slot = /const testResults=\{EndOfJson:"EndOfJson"\}/;
if (!slot.test(template)) throw new Error('The template has no data slot (const testResults={EndOfJson:"EndOfJson"}).');
const html = template
	.replace(slot, () => `const testResults=${json.replace(/<\//g, '<\\/')}`)
	// The report loads its product and feature icons from maester.dev; the demo takes them from the site it is on
	// (public/report-icons), so it shows them in previews and locally too.
	.replaceAll('https://maester.dev/report-icons/', '/report-icons/')
	.replace('<head>', '<head>\n    <meta name="robots" content="noindex">');

mkdirSync(dirname(out.pathname), { recursive: true });
writeFileSync(out, html);
console.log(`Wrote ${out.pathname} (${Math.round(html.length / 1024)} KB).`);
