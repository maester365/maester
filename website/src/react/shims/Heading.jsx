export default function Heading({ as: Tag = 'h2', children, ...rest }) {
	return <Tag {...rest}>{children}</Tag>;
}
