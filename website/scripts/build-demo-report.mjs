// Builds public/demo/report.html: the real Maester HTML report filled with sample results, for the home page and
// the "Open the demo report" link. Run it when the report template or its sample data changes.
//
// Usage (from website/):
//   node scripts/build-demo-report.mjs <report template .html> <sample results .ts or .json> [--attach <name>=<file>]...
//
// The template is the built report (report/dist/index.html, or powershell/assets/ReportTemplate.html once it is
// released). The sample is report/src/lib/testResults.ts, the data the report's own dev server uses, or the
// results.json that report/scripts/export-demo-data.mjs writes from it with what a real run adds (the Zero Trust
// Assessment pack's menu, affected objects, earlier runs). The sample comes from a real demo tenant, so its names,
// domains and IDs are replaced with Contoso before it is published.
//
// Each --attach embeds a file the way Add-MtReportAttachment does: an .html file is a report the pack's menu opens
// (the Zero Trust Assessment's own report, named "Zero Trust Assessment"), a .json file is data a view reads (the
// Zero Trust plan, named "zero-trust-workshop", from export-demo-data.mjs). Attachments get the same replacements,
// and the build fails if a name of the demo tenant is left in any of them.
//
// The full refresh, from the repository root:
//   (cd report && npm run build && node scripts/export-demo-data.mjs /tmp/maester-demo)
//   (cd website && node scripts/build-demo-report.mjs ../report/dist/index.html /tmp/maester-demo/results.json \
//      --attach "zero-trust-workshop=/tmp/maester-demo/zero-trust-workshop.json" \
//      --attach "Zero Trust Assessment=<a ZeroTrustAssessmentReport.html of the demo tenant>")
//   (cd website && node scripts/capture-demo-report.mjs http://localhost:4321)
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { gzipSync } from 'node:zlib';

const args = process.argv.slice(2);
const attachArgs = [];
const positional = [];
for (let i = 0; i < args.length; i++) {
	if (args[i] === '--attach') attachArgs.push(args[++i] ?? '');
	else positional.push(args[i]);
}
const [templatePath, dataPath] = positional;
if (!templatePath || !dataPath || attachArgs.some((a) => !/^[^=]+=.+/.test(a))) {
	console.error('Usage: node scripts/build-demo-report.mjs <report template .html> <sample results .ts|.json> [--attach <name>=<file>]...');
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
	// More people in the demo tenant, as they appear in the Zero Trust Assessment's report.
	[/Aahmed Test/g, 'Allan Test'],
	[/Afif Ahmed/g, 'Allan Deyoung'],
	[/\bAfif\b/g, 'Allan'],
	[/Anna Jorayew/g, 'Debra Berger'],
	[/Faiza Malkia/g, 'Irvin Sayers'],
	[/Hamisi Khari/g, 'Enrico Cattaneo'],
	[/Jackie Fernandez/g, 'Christie Cline'],
	[/Manoj Kesana/g, 'Raul Razo'],
	[/Rhea Stone/g, 'Cameron White'],
	[/Richard Wilkings/g, 'Ben Walters'],
	[/Roi Fraguela/g, 'Brian Johnson'],
	[/Sarah Mehrotra/g, 'Sara Davis'],
	[/Shonali Balakrishna/g, 'Alan Steiner'],
	[/Simon Burn/g, 'Adam Barr'],
	[/Tegra N[uú]nez/g, 'Kim Akers'],
	[/Tracy yu/gi, 'Pat Coleman'],
	[/Ty Grady/g, 'Toni Poe'],
	[/Tyler\.GradyTaylor_microsoft\.com/g, 'toni.poe_fabrikam.com'],
	[/Wilna Rossouw/g, 'Dan Jump'],
	[/Yakup Meredow/g, 'Ivan Irons'],
	[/\bpraneeth-test\b/g, 'pat-test'],
	[/\bmanoj-test\b/g, 'raul-test'],
	[/\bkomal-test\b/g, 'patti-test'],
	[/\baahmed-test\b/g, 'allan-test'],
	[/\btygradytest\b/g, 'tonitest'],
	[/MaduraTestVM/g, 'MeganTestVM'],
	[/\bsandeep\.p\b/g, 'sandy.p'],
	[/Merill Fernando/g, 'Adele Vance'],
	[/\bMerill\b/g, 'Adele'],
	[/\bmerill\b/g, 'adele'],
];

const results = loadResults(dataPath);
delete results.TenantLogos;
const tenantId = results.TenantId;
const demoTenantId = '6f1a2b3c-4d5e-4f60-8a7b-9c0d1e2f3a4b';
// Every personal address becomes a demo persona; addresses that name a role or a test object stay. The map is shared,
// so an address gets the same persona in the result and in every attachment.
const personas = ['alex.wilber', 'lee.gu', 'nestor.wilke', 'megan.bowen', 'isaiah.langer', 'diego.siciliani', 'lidia.holloway', 'lynne.robbins', 'miriam.graham', 'johanna.lorenz', 'joni.sherman', 'pradeep.gupta', 'patti.fernandez', 'christie.cline', 'grady.archie', 'henrietta.mueller'];
const roleAddress = /^(admin|emergency|emergency_\d+|unlicensed|nomailenabled|nousagelocation|usernonick|new|breakglass\d*|emergencyaccessgroup|aitest\d+|agentuser\d+|agent\.\w+|sync_dc\d*_\w+|testsposessionenforced)$/i;
const addresses = new Map();
// Short names count only as whole words, so the Base64 of an icon doesn't trip the check.
const leftoverPattern = /elapora|pora\.onmicrosoft|merill|kalwani|sonnadara|atayewa|quinzon|nikolic|perennial|shobalak|kesana|praneeth|shonali|balakrishna|rossouw|meredow|jorayew|malkia|fraguela|wilkings|mehrotra|tygrady|ty grady|gradytaylor|\b(?:pora|varsha|tyler|joshua|madura|afif|manoj|sandeep|komal|chukka|hamisi)\b/i;

/** The text with the demo tenant's names, domains, people and ID replaced; fails if any is left. */
function scrub(text, what) {
	let s = text.replaceAll(tenantId, demoTenantId);
	for (const [pattern, value] of replacements) s = s.replace(pattern, value);
	s = s.replace(/\b([A-Za-z0-9._#-]+)@(contoso(?:\.mail)?(?:\.onmicrosoft)?\.com)\b/g, (match, local, domain) => {
		if (roleAddress.test(local)) return match;
		const key = local.toLowerCase();
		if (!addresses.has(key)) addresses.set(key, personas[addresses.size % personas.length] + (addresses.size >= personas.length ? String(Math.floor(addresses.size / personas.length) + 1) : ''));
		return `${addresses.get(key)}@${domain}`;
	});
	const leftover = s.match(leftoverPattern) ?? s.match(new RegExp(tenantId, 'i'));
	if (leftover) {
		const at = leftover.index ?? 0;
		throw new Error(`${what} still names the demo tenant: ${leftover[0]} (…${s.slice(Math.max(0, at - 60), at + 60)}…)`);
	}
	return s;
}

// The attachments, as Add-MtReportAttachment embeds them: listed in the result, the content gzip-compressed and
// Base64-encoded in a <script type="application/octet-stream"> element of its own.
const attachments = attachArgs.map((arg, i) => {
	const [name, ...rest] = arg.split('=');
	const file = rest.join('=');
	const json = /\.json$/i.test(file);
	const content = scrub(readFileSync(file, 'utf8'), `The attachment "${name}"`);
	const id = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || `attachment-${i + 1}`;
	return {
		meta: { Id: id, Name: name, TestId: null, ContentType: json ? 'application/json' : 'text/html', FileName: file.split('/').pop(), Size: Buffer.byteLength(content) },
		base64: gzipSync(Buffer.from(content, 'utf8'), { level: 9 }).toString('base64'),
	};
});
if (attachments.length) results.Attachments = [...(results.Attachments ?? []).filter((a) => !attachments.some((x) => x.meta.Name === a?.Name)), ...attachments.map((a) => a.meta)];
const json = scrub(JSON.stringify(results), 'The sample');

const template = readFileSync(templatePath, 'utf8');
const slot = /const testResults=\{EndOfJson:"EndOfJson"\}/;
if (!slot.test(template)) throw new Error('The template has no data slot (const testResults={EndOfJson:"EndOfJson"}).');
const html = template
	.replace(slot, () => `const testResults=${json.replace(/<\//g, '<\\/')}`)
	// The report loads its product and feature icons from maester.dev; the demo takes them from the site it is on
	// (public/report-icons), so it shows them in previews and locally too.
	.replaceAll('https://maester.dev/report-icons/', '/report-icons/')
	.replace('<head>', '<head>\n    <meta name="robots" content="noindex">')
	.replace(/<\/body>(?![\s\S]*<\/body>)/, () => `${attachments.map((a) => `<script type="application/octet-stream" id="maester-attachment-${a.meta.Id}" data-encoding="gzip+base64">${a.base64}</script>`).join('\n')}\n</body>`);

mkdirSync(dirname(out.pathname), { recursive: true });
writeFileSync(out, html);
console.log(`Wrote ${out.pathname} (${Math.round(html.length / 1024)} KB).`);
