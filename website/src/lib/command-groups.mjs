// The commands, grouped by job: the folder each one lives in under powershell/public (run/, connect/, services/entra/…),
// which the generated page names in its editUrl. Used by the commands sidebar (astro.config.mjs) and the commands
// overview (components/CommandList.astro), so both list the same groups in the same order.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

/** The two commands nearly everyone runs: first in the sidebar and on the overview. */
export const keyCommands = ['Connect-Maester', 'Invoke-Maester'];

// Folder (or folders) -> group, in the order they are listed.
const groups = [
	{ id: 'connect', label: 'Connect', folders: ['connect'], about: 'Sign in to Microsoft 365, Azure, Active Directory and GitHub, and manage the session and its caches.' },
	{ id: 'run', label: 'Run and write tests', folders: ['run'], about: 'Run the checks, find and write tests, and record what a test found.' },
	{ id: 'report', label: 'Reports and alerts', folders: ['report'], about: 'Build, merge and compare reports, and send the results by email or to Teams.' },
	{ id: 'packs', label: 'Maester Packs', folders: ['packs'], about: 'Install, update and build packs of extra checks.' },
	{ id: 'app', label: 'Automation setup', folders: ['app'], about: 'Create and update the app registration that runs Maester in a pipeline.' },
	{ id: 'entra', label: 'Entra and Microsoft Graph', folders: ['services/graph', 'services/entra'], about: 'Read users, roles, groups, licences and Conditional Access from Microsoft Graph, for your own tests.' },
	{ id: 'exchange', label: 'Exchange and email', folders: ['services/exchange'], about: 'Read Exchange Online settings and check a domain’s SPF, DKIM, DMARC and MX records.' },
	{ id: 'azure', label: 'Azure and SharePoint', folders: ['services/azure', 'services/sharepoint'], about: 'Call Azure Resource Manager and Resource Graph, and read SharePoint Online settings.' },
	{ id: 'ad', label: 'Active Directory', folders: ['services/ad'], about: 'Read on-premises Active Directory state for the AD checks.' },
];

const commandsDir = join(process.cwd(), 'docs/commands');

/** Every command page: name, what it does, and its group. */
export function commands() {
	return readdirSync(commandsDir)
		.filter((file) => file.endsWith('.mdx') && file !== 'readme.mdx')
		.map((file) => {
			const text = readFileSync(join(commandsDir, file), 'utf8');
			const name = file.replace(/\.mdx$/, '');
			const folder = text.match(/^editUrl:.*powershell\/public\/(.+)\/[^/]+\.ps1\s*$/m)?.[1] ?? '';
			const description = text.match(/^description:\s*"?(.*?)"?\s*$/m)?.[1] ?? '';
			const group = groups.find((g) => g.folders.includes(folder))?.id ?? 'other';
			return { name, description, group };
		})
		.sort((a, b) => a.name.localeCompare(b.name));
}

/** The groups with their commands, in order. A command in a folder no group names goes under "Other". */
export function commandGroups() {
	const all = commands();
	const listed = groups.map((g) => ({ ...g, commands: all.filter((c) => c.group === g.id) }));
	const other = all.filter((c) => c.group === 'other');
	if (other.length) listed.push({ id: 'other', label: 'Other', folders: [], about: '', commands: other });
	return listed.filter((g) => g.commands.length > 0);
}

/** The commands sidebar: the key commands first, then each group (the key commands aren't repeated in theirs). */
export function commandsSidebar() {
	const link = (name, attrs = {}) => ({ label: name, link: `/docs/commands/${name}`, attrs: { title: name, ...attrs } });
	return [
		{ label: 'Overview', link: '/docs/commands' },
		{ label: 'Start here', items: keyCommands.map((name) => link(name, { class: 'mt-key-command' })) },
		...commandGroups().map((g) => ({
			label: g.label,
			collapsed: g.folders.every((f) => f.startsWith('services/')),
			items: g.commands.filter((c) => !keyCommands.includes(c.name)).map((c) => link(c.name)),
		})),
	];
}
