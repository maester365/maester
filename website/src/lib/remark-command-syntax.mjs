// A command page's syntax block keeps the line breaks PlatyPS wrote (one group of parameters a line) instead of
// wrapping inside a parameter like "[-\nProduct <String[]>]": the block scrolls sideways instead, and the page
// shortens a long one behind "Show full syntax" (see overrides/PageTitle.astro).
const commandFile = /[\\/]website[\\/]docs[\\/]commands[\\/]([^\\/]+)\.mdx$/;

export function remarkCommandSyntax() {
	return (tree, file) => {
		if (!commandFile.test(file.path ?? '')) return;
		let inSyntax = false;
		for (const node of tree.children) {
			if (node.type === 'heading') inSyntax = node.depth === 2 && node.children.map((c) => c.value ?? '').join('').trim().toUpperCase() === 'SYNTAX';
			else if (inSyntax && node.type === 'code') node.meta = [node.meta, 'wrap=false'].filter(Boolean).join(' ');
		}
	};
}
