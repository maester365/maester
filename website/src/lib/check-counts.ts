// How many checks Maester has, counted once for every page that says so (the home page and the pricing page), so the
// numbers can't disagree. The catalogs are written before each build by scripts/prepare-data.mjs, and the
// build-website workflow builds on every push to main and once a day, which picks up new community packs.
import explorer from '../data/explorer.json';
import catalog from '../data/test-catalog.json';
import ztaCatalog from '../../../packs/zero-trust-assessment/catalog.json';

/** The checks in the module, without the deprecated ones. */
export const tests = (catalog.Tests as any[]).filter((t) => t.Lifecycle !== 'Deprecated');
export const builtIn = tests.length;
/** The Zero Trust Assessment pack, which ships with Maester. */
export const zta = (ztaCatalog.Tests as unknown[]).length;
/** Everything a Maester install runs out of the box. */
export const core = builtIn + zta;
/** Community pack checks on packs.maester.cloud, by the packs' own counts (community-packs.mjs). */
export const community = (explorer.communityPacks as { count: number }[]).reduce((n, p) => n + p.count, 0);
export const total = core + community;
export const format = (n: number) => n.toLocaleString('en-US');
