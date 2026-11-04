// Tidies a command reference page: headings in sentence case, and a version mark on each "-Name" heading whose
// parameter the stable release does not have.
import { commandHistory, previewLabel, stableVersion } from './versions.mjs';

const commandFile = /[\\/]website[\\/]docs[\\/]commands[\\/]([^\\/]+)\.mdx$/;

function text(node) {
	if (node.type === 'text') return node.value;
	return (node.children ?? []).map(text).join('');
}

export function rehypeCommandParameters() {
	return (tree, file) => {
		const name = file.path?.match(commandFile)?.[1];
		if (!name) return;
		// PlatyPS headings are in capitals (SYNOPSIS, EXAMPLE 1): write them in sentence case.
		const sentence = (node) => {
			if (node.type === 'element' && /^h[23]$/.test(node.tagName)) {
				const t = text(node).trim();
				if (/^[A-Z][A-Z0-9 ]+$/.test(t) && node.children.length === 1 && node.children[0].type === 'text') {
					node.children[0].value = t.charAt(0) + t.slice(1).toLowerCase();
				}
			}
			for (const child of node.children ?? []) sentence(child);
		};
		sentence(tree);
		const history = commandHistory(name);
		// A command the stable release doesn't have: the page says so once, at the top.
		if (!history) return;
		const visit = (node) => {
			if (node.type === 'element' && node.tagName === 'h3') {
				const parameter = text(node).trim().match(/^-([A-Za-z][A-Za-z0-9]*)$/)?.[1];
				if (parameter && parameter !== 'ProgressAction' && !history.parameters.has(parameter)) {
					node.children.push({
						type: 'element',
						tagName: 'span',
						properties: { className: ['mt-mark'], title: `Not in Maester ${stableVersion}` },
						children: [
							{ type: 'element', tagName: 'span', properties: { className: ['mt-mark__preview'] }, children: [{ type: 'text', value: `New in ${previewLabel}` }] },
							{ type: 'element', tagName: 'span', properties: { className: ['mt-mark__stable'] }, children: [{ type: 'text', value: `Preview ${previewLabel}` }] },
						],
					});
				}
			}
			for (const child of node.children ?? []) visit(child);
		};
		visit(tree);
	};
}
