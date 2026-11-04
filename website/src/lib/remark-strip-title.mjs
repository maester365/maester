// Docusaurus pages often start with "# Title"; Starlight prints the title already, so drop a leading H1.
export function remarkStripTitle() {
	return (tree) => {
		const first = tree.children.findIndex((node) => !['mdxjsEsm', 'yaml', 'toml', 'html'].includes(node.type) || (node.type === 'html' && !/^<!--/.test(node.value)));
		if (first !== -1 && tree.children[first].type === 'heading' && tree.children[first].depth === 1) tree.children.splice(first, 1);
	};
}
