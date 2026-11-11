// The built-in tests with the attributes the test builder can load, so "Start from an existing test" does not ship
// the whole catalog with the page. Read on demand by src/components/TestBuilder/index.jsx.
import type { APIRoute } from 'astro';
import catalog from '../../data/test-catalog.json';

const keep = [
	'Id', 'Title', 'Suite', 'FunctionName', 'Product', 'RelatedProduct', 'Feature', 'Area', 'ResourceType', 'Severity', 'UserImpact', 'ImplementationCost',
	'Mitre', 'Control', 'Service', 'License', 'Permission', 'TenantType', 'Cloud', 'Platform', 'Lifecycle', 'ReplacedBy', 'LongRunning', 'Exclusive',
	'Author', 'Contributor', 'Parameters',
] as const;

export const GET: APIRoute = () => {
	const tests = (catalog.Tests as Record<string, unknown>[]).map((test) => Object.fromEntries(keep.filter((key) => key in test).map((key) => [key, test[key]])));
	return new Response(JSON.stringify(tests), { headers: { 'Content-Type': 'application/json' } });
};
