// A link in the React components: a plain <a> (they came from the Docusaurus site, which had its own Link).
export default function Link({ to, href, children, ...rest }) {
	return (
		<a href={to ?? href} {...rest}>
			{children}
		</a>
	);
}
