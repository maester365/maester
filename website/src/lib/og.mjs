// The Open Graph image of each page: a 1200×630 card with the page's section, title and description, rendered after
// the build by scripts/og-images.mjs. A page writes its card into a <meta name="maester:og"> tag, which the script
// reads (and removes), and links /og/<page>.jpg?v=<hash> as its og:image. The hash changes only when the card does,
// so a link preview that LinkedIn, X or Teams has cached is refreshed only when the page's card changes.
import { createHash } from 'node:crypto';

/** Change this when the card's design changes, so every card is rendered again and every hash changes. */
export const CARD_VERSION = 1;
export const CARD_WIDTH = 1200;
export const CARD_HEIGHT = 630;

/** The card of the pages that have none of their own: the 2.x archive and the lists that are kept out of search. */
export const defaultCard = {
	path: 'default',
	title: 'Test your Microsoft 365 security, every day, in one run.',
	description: 'Open-source security testing for Microsoft 365, Entra, Azure and Active Directory.',
};

export function cardHash(card) {
	return createHash('sha256').update(JSON.stringify([CARD_VERSION, card])).digest('hex').slice(0, 12);
}

/** The image path for a page path: / is og/index.jpg, /docs/tests/MT.1001 is og/docs/tests/MT.1001.jpg. */
export function cardPath(pagePath) {
	const path = pagePath.replace(/(index)?\.html$/, '').replace(/^\/+|\/+$/g, '');
	return path === '' ? 'index' : path;
}

/** The og:image URL of a card. */
export function cardUrl(card, site = 'https://maester.dev') {
	return new URL(`/og/${card.path}.jpg?v=${cardHash(card)}`, site).href;
}

/**
 * The card of a docs page, from its route and frontmatter. Tests show their ID, severity, product and feature;
 * commands show their name in the code font.
 */
export function docsCard(id, data) {
	const card = docsCardOf(id, data);
	// Many benchmark tests repeat their title as their description; show it once.
	const words = (text) => String(text ?? '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
	if (card.description && words(card.description).startsWith(words(card.title).slice(0, 40))) delete card.description;
	return card;
}

function docsCardOf(id, data) {
	const facts = data.maester;
	if (facts?.kind === 'test') {
		return {
			path: cardPath(`/${id}`),
			label: 'Test catalog',
			title: data.title,
			description: data.description,
			id: facts.id,
			severity: facts.severity,
			chips: [facts.product, facts.feature].filter(Boolean),
		};
	}
	if (facts?.kind === 'command' || id.startsWith('docs/commands/')) {
		return { path: cardPath(`/${id}`), label: 'Command', title: data.title, description: data.description, code: true };
	}
	const label = id.startsWith('docs/tests') ? 'Test catalog' : id.startsWith('docs/packs') ? 'Packs' : id.startsWith('docs/commands') ? 'Commands' : 'Docs';
	return { path: cardPath(`/${id}`), label, title: data.title, description: data.description };
}
