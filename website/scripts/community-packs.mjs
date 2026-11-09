// The community packs listed on packs.maester.cloud, with their tests, for the test catalog and the home page:
// src/data/community-packs.json, which git ignores. prepare-data.mjs runs this before generate-test-docs.mjs, which
// adds the tests to the catalog explorer marked as a community pack's.
//
// packs.maester.cloud/catalog.json lists every listed pack with its tests. Until it is served, index.json gives each
// pack with its test count only, and the catalog lists no community tests. A pack with the BuiltIn badge ships with
// Maester (packs/ in this repository) and is read from there, so it is left out here. When the index can't be reached,
// the file has no packs and the build goes on: the next daily build picks them up.
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const websiteRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
export const communityPacksPath = join(websiteRoot, "src", "data", "community-packs.json");
const site = process.env.MAESTER_PACKS_URL ?? "https://packs.maester.cloud";

async function fetchJson(url) {
  const response = await fetch(url, { signal: AbortSignal.timeout(15000), headers: { "User-Agent": "maester.dev build" } });
  if (!response.ok) throw new Error(`${url}: ${response.status}`);
  return response.json();
}

// The pack's banner image on packs.maester.cloud, when it has one: only an https URL, and a value that isn't a URL
// costs that pack its banner, not the whole list.
function bannerUrl(value) {
  if (!value) return "";
  try {
    const url = new URL(value, `${site}/`);
    return url.protocol === "https:" ? url.href : "";
  } catch {
    return "";
  }
}

const list = (value) => (value == null ? [] : Array.isArray(value) ? value : [value]);

function pack(p, tests) {
  const code = p.Code;
  return {
    id: p.Id,
    code,
    name: p.Name,
    description: p.Description ?? "",
    publisher: p.Owner ?? "",
    version: p.Version ?? "",
    badges: list(p.Badges),
    products: list(p.Products),
    url: p.Url ?? `${site}/p/${code.toLowerCase()}`,
    banner: bannerUrl(p.Banner),
    count: tests ? tests.length : (p.Tests ?? 0),
    tests: (tests ?? []).map((t) => ({
      id: t.Id,
      title: t.Title,
      severity: t.Severity || "Info",
      product: list(t.Product)[0] ?? "",
      pillar: list(t.Pillar),
      category: t.Category ?? "",
      url: t.Url ?? `${site}/p/${code.toLowerCase()}/tests`,
    })),
  };
}

async function read() {
  try {
    const catalog = await fetchJson(`${site}/catalog.json`);
    // catalog.json has each pack's tests but not its banner; index.json has the banner.
    const banners = new Map();
    try {
      for (const p of list((await fetchJson(`${site}/index.json`)).Packs)) if (p?.Code && p.Banner) banners.set(p.Code, p.Banner);
    } catch (error) {
      console.log(`community-packs: no index.json (${error.message}), the packs have no banners`);
    }
    return { source: "catalog", generatedAt: catalog.GeneratedAt ?? null, packs: list(catalog.Packs).map((p) => [{ Banner: banners.get(p.Code), ...p }, list(p.Tests)]) };
  } catch (error) {
    console.log(`community-packs: no catalog.json (${error.message}), reading the test counts from index.json`);
  }
  const index = await fetchJson(`${site}/index.json`);
  return { source: "index", generatedAt: index.GeneratedAt ?? null, packs: list(index.Packs).map((p) => [p, null]) };
}

export async function writeCommunityPacks() {
  let data = { source: "none", generatedAt: null, packs: [] };
  try {
    const result = await read();
    // An entry without a code or name is skipped rather than dropping every pack.
    const packs = result.packs
      .filter(([p]) => p?.Code && p?.Name && !list(p.Badges).includes("BuiltIn"))
      .map(([p, tests]) => pack(p, tests));
    packs.sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));
    data = { source: result.source, generatedAt: result.generatedAt, packs };
  } catch (error) {
    console.warn(`community-packs: could not read ${site}: ${error.message}. The site lists no community packs.`);
  }
  // eslint-disable-next-line security/detect-non-literal-fs-filename -- a file of this repository
  writeFileSync(communityPacksPath, `${JSON.stringify({ $comment: "Written by website/scripts/community-packs.mjs. Do not edit.", ...data })}\n`);
  const tests = data.packs.reduce((n, p) => n + p.count, 0);
  console.log(`community-packs: ${data.packs.length} packs, ${tests} tests (from ${data.source})`);
  return data;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await writeCommunityPacks();
