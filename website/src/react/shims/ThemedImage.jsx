// Shows the light or dark source with CSS, so the static HTML is right in both themes.
export default function ThemedImage({ sources, alt, className = '', ...rest }) {
	return (
		<>
			<img {...rest} src={sources.light} alt={alt} className={`${className} mt-light-only`.trim()} />
			<img {...rest} src={sources.dark} alt={alt} className={`${className} mt-dark-only`.trim()} />
		</>
	);
}
