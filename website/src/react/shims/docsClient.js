// Every test page in contributors.json exists on this site (the pages are built from the same catalog), so the
// contributor pages can link them all.
import contributors from '../../data/contributors.json';

export function useDocsData() {
	const docs = Object.values(contributors.tests ?? {}).map((test) => ({ path: test.path }));
	return { versions: [{ docs }] };
}
