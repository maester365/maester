// The built-in tests with the attributes the test builder can load, so "Start from an existing test" does not ship
// the whole catalog with the page. Read on demand by src/components/TestBuilder/index.jsx.
import type { APIRoute } from 'astro';
import catalog from '../../data/test-catalog.json';

const keep = new Set<string>([
	'Id', 'Title', 'Suite', 'FunctionName', 'Product', 'RelatedProduct', 'Feature', 'Area', 'ResourceType', 'Severity', 'UserImpact', 'ImplementationCost',
	'Mitre', 'Control', 'Service', 'License', 'Permission', 'TenantType', 'Cloud', 'Platform', 'Lifecycle', 'ReplacedBy', 'LongRunning', 'Exclusive',
	'Author', 'Contributor', 'Parameters',
]);

export const GET: APIRoute = () => {
	const tests = (catalog.Tests as Record<string, unknown>[]).map((test) => Object.fromEntries(Object.entries(test).filter(([key]) => keep.has(key))));
	return new Response(JSON.stringify(tests), { headers: { 'Content-Type': 'application/json' } });
};
