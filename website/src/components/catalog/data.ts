// Build-time data of the test catalog explorer: src/data/explorer.json, written by scripts/catalog-explorer.mjs.
import explorer from '../../data/explorer.json';
import { productIcon, productInitials, featureIcon } from '../../lib/report-icons.mjs';
import { previewLabel } from '../../lib/versions.mjs';

export type Check = (typeof explorer.tests)[number] & { pillar?: string[]; category?: string; also?: string[]; testId?: string };
export const data = explorer;
export const checks = explorer.tests as Check[];
export const severityOrder = ['Critical', 'High', 'Medium', 'Low', 'Info'];
export const ratingOrder = ['Low', 'Medium', 'High'];
export { previewLabel, productIcon, productInitials, featureIcon };

export const productName = (key: string) => explorer.products.find((p) => p.key === key)?.name ?? key;
export const packOf = (code: string) => explorer.packs.find((p) => p.code === code);
export const frameworkOf = (key: string) => explorer.frameworks.find((f) => f.key === key);
export const checkUrl = (id: string) => `/docs/tests/${id}`;

// The suites of the nav, by their key in the URL of their page (/docs/tests/<key>).
export const suiteInfo: Record<string, { name: string; slug: string }> = {
	Maester: { name: 'Maester', slug: 'maester' },
	CIS: { name: 'CIS', slug: 'cis' },
	CISA: { name: 'CISA SCuBA', slug: 'cisa' },
	ASD: { name: 'ASD Essential Eight', slug: 'asd' },
	EIDSCA: { name: 'Entra ID SCA (EIDSCA)', slug: 'eidsca' },
	ORCA: { name: 'ORCA', slug: 'orca' },
	AD: { name: 'Active Directory', slug: 'ad' },
	XSPM: { name: 'Exposure management (XSPM)', slug: '' },
};

// The channel of a check for the filter: new in the preview, runs only with -IncludePreview, or both.
export const channelOf = (t: Check) => [t.previewOnly && !t.pack ? 'new' : '', t.previewCheck ? 'preview' : ''].filter(Boolean).join(' ');
// The text the catalog's search looks in.
export const searchText = (t: Check) => `${t.id} ${t.title} ${t.productName} ${t.featureName} ${t.areaName} ${t.mitre.join(' ')} ${t.category ?? ''}`.toLowerCase();

// The suites a suite's page lists: XSPM has no page, and its MT checks have their pages under Maester's.
export const suiteMembers = (suite: string) => (suite === 'Maester' ? ['Maester', 'XSPM'] : [suite]);

const pillarNames = new Map([['SecOps', 'Security operations']]);
export const pillarName = (p: string) => pillarNames.get(p) ?? p;

export function severityMix(list: Check[]) {
	return severityOrder.map((s) => ({ key: s, count: list.filter((t) => t.severity === s).length })).filter((s) => s.count);
}

export const plural = (n: number, word: string) => `${n.toLocaleString('en-US')} ${word}${n === 1 ? '' : 's'}`;
