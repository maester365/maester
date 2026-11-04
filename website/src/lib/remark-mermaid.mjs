// ```mermaid code blocks become <pre class="mermaid"> for the client-side renderer (components/Mermaid.astro),
// before Expressive Code would turn them into a highlighted code block.
export function remarkMermaid() {
	return (tree) => {
		const visit = (node) => {
			for (const [i, child] of (node.children ?? []).entries()) {
				if (child.type === 'code' && child.lang === 'mermaid') {
					const escaped = child.value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
					node.children[i] = { type: 'html', value: `<pre class="mermaid not-content">${escaped}</pre>` };
				} else visit(child);
			}
		};
		visit(tree);
	};
}
