// A plain-text summary of Markdown for a meta description: the first real paragraph, without Markdown syntax, cut
// at a sentence or word boundary at most `max` characters long. Used for test pages (scripts/generate-test-docs.mjs)
// and for any docs page without a description of its own (src/routeData.ts).

// Removes HTML comments (which end at "-->" or "--!>") and MDX comments, as HTML does: a comment with no end runs to
// the end of the text. It scans rather than using a regular expression, and repeats until no opener is left, since
// removing one comment can join the pieces of another ("<!<!---->--").
function stripComments(text) {
	const comments = [
		{ open: '<!--', close: ['-->', '--!>'] },
		{ open: '{/*', close: ['*/}'] },
	];
	for (;;) {
		const found = comments.map((c) => ({ ...c, at: text.indexOf(c.open) })).filter((c) => c.at !== -1);
		if (found.length === 0) return text;
		const { open, close, at } = found.reduce((a, b) => (b.at < a.at ? b : a));
		const ends = close.map((end) => [text.indexOf(end, at + open.length), end.length]).filter(([i]) => i !== -1);
		const end = ends.length ? Math.min(...ends.map(([i, length]) => i + length)) : text.length;
		text = text.slice(0, at) + text.slice(end);
	}
}

export function plain(markdown) {
	return stripComments(String(markdown ?? '').replace(/^---[\s\S]*?^---/m, '').replace(/^(import|export)\s.*$/gm, ''))
		.replace(/^(```|~~~)[\s\S]*?^\1/gm, '')
		.replace(/<[^>]+>/g, ' ')
		.replace(/!\[[^\]]*\]\([^)]*\)/g, '')
		.replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
		.replace(/https?:\/\/\S+/g, '')
		.replace(/`([^`]*)`/g, '$1')
		.replace(/(\*\*|__|\*|_)(\S[^*_]*?)\1/g, '$2')
		.replace(/\\([!-/:-@[-`{-~])/g, '$1');
}

export function summarize(markdown, max = 155) {
	const blocks = plain(markdown)
		.split(/\n\s*\n/)
		.map((b) => b.trim())
		// Skip headings, admonitions, tables, lists of links and labels such as "Learn more:".
		.filter((b) => b && !/^(#{1,6}\s|:::|\||[-*+]\s|\d+\.\s|>\s)/.test(b) && b.replace(/\s+/g, ' ').length >= 40);
	const first = blocks[0]?.replace(/\s+/g, ' ').replace(/\s*(Learn more|See also|Remediation action):?.*$/i, '').trim();
	if (!first) return '';
	if (first.length <= max) return first;
	const cut = first.slice(0, max);
	const sentence = cut.match(/^(.{60,}[.!?])\s/);
	if (sentence) return sentence[1];
	return `${cut.slice(0, cut.lastIndexOf(' ')).replace(/[,;:\s]+$/, '')}…`;
}
