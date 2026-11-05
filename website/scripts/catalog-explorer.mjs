// The data of the test catalog explorer (src/components/catalog/): every check, the built-in tests and the tests of
// the packs that ship with Maester, with the taxonomy, the frameworks by requirement and the ATT&CK release, in one
// file the explorer's components read: src/data/explorer.json, which git ignores. generate-test-docs.mjs writes it,
// with the pages, from src/data/test-catalog.json and the framework files of the suites.

import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const websiteRoot = join(scriptDir, "..");
const repoRoot = join(websiteRoot, "..");
export const explorerPath = join(websiteRoot, "src", "data", "explorer.json");

const severityOrder = ["Critical", "High", "Medium", "Low", "Info"];

// The structure each framework is read in: CIS sections, CISA services, Essential Eight strategies, ISM guidelines.
const CIS_M365_SECTIONS = {
  1: "Microsoft 365 admin center",
  2: "Microsoft 365 Defender",
  3: "Microsoft Purview",
  4: "Microsoft Intune",
  5: "Microsoft Entra admin center",
  6: "Exchange admin center",
  7: "SharePoint admin center",
  8: "Microsoft Teams admin center",
  9: "Microsoft Fabric",
};
const CIS_GITHUB_SECTIONS = { 1: "Source code", 2: "Build pipelines", 3: "Dependencies", 4: "Artifacts", 5: "Deployment" };
const CISA_SERVICES = {
  "MS.AAD": "Entra ID",
  "MS.DEFENDER": "Defender",
  "MS.EXO": "Exchange Online",
  "MS.POWERBI": "Power BI",
  "MS.POWERPLATFORM": "Power Platform",
  "MS.SHAREPOINT": "SharePoint",
  "MS.TEAMS": "Teams",
  "MS.SECURITYSUITE": "Security suite",
};

// Each framework of the nav, in the nav's order (NIST first): its short code, the suite that runs it and how its requirements are grouped. A
// framework whose file lists only the requirements Maester checks (CIS GitHub, ISM) has no coverage figure.
export const frameworkConfig = {
  "nist-800-53-r5": { code: "NIST", label: "NIST SP 800-53 r5", suite: "", complete: false, section: (r) => r.Family || "Other" },
  "cis-m365": { code: "CIS", label: "CIS Microsoft 365", suite: "cis", complete: true, section: (r) => sectionName(CIS_M365_SECTIONS, r.Id.split(".")[0]) },
  "cis-github": { code: "CIS", label: "CIS GitHub", suite: "cis", complete: false, section: (r) => sectionName(CIS_GITHUB_SECTIONS, r.Id.split(".")[0]) },
  "cisa-scuba": { code: "CISA", label: "CISA SCuBA", suite: "cisa", complete: true, section: (r) => sectionName(CISA_SERVICES, r.Id.split(".").slice(0, 2).join(".")) },
  "essential-eight": { code: "E8", label: "Essential Eight", suite: "asd", complete: true, section: (r) => [r.Strategy].flat().filter(Boolean) },
  ism: { code: "ISM", label: "ASD ISM", suite: "asd", complete: false, section: (r) => r.Guideline || "Other" },
};

// A GitHub avatar at the size the nav shows it (github.com/<handle>.png serves the full image otherwise).
function smallAvatar(url) {
  return /^https:\/\/github\.com\/[^/]+\.png$/.test(url) ? `${url}?size=40` : url;
}

function sectionName(names, key) {
  const name = new Map(Object.entries(names)).get(key);
  return name ? `${key} · ${name}` : key;
}

function readJson(path) {
  // eslint-disable-next-line security/detect-non-literal-fs-filename -- paths in this repository
  return JSON.parse(readFileSync(path, "utf8"));
}

// The framework files of the suites (tests/<suite>/frameworks/<key>.json) and the pinned NIST list.
function loadFrameworkFiles() {
  const files = new Map();
  for (const suite of readdirSync(join(repoRoot, "tests"))) {
    const folder = join(repoRoot, "tests", suite, "frameworks");
    // eslint-disable-next-line security/detect-non-literal-fs-filename -- a folder of this repository
    if (!existsSync(folder)) continue;
    // eslint-disable-next-line security/detect-non-literal-fs-filename -- a folder of this repository
    for (const name of readdirSync(folder).filter((n) => n.endsWith(".json"))) {
      const file = readJson(join(folder, name));
      files.set(file.Framework, { name: file.Name, version: file.Version, url: file.Url ?? "", requirements: file.Requirements });
    }
  }
  const nist = readJson(join(repoRoot, "powershell", "assets", "MaesterNistControls.json"));
  files.set("nist-800-53-r5", {
    name: nist.Name ?? "NIST SP 800-53 Rev. 5",
    version: nist.Version ?? "",
    url: "https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final",
    requirements: nist.Controls.map((c) => ({ Id: c.Id, Title: c.Title, Family: c.Family })),
  });
  return files;
}

// Writes src/data/explorer.json. releasedTests is the set of test IDs of the stable release (versions.json);
// contributors is the credit data of contributors.mjs (attributions by test ID, and profiles).
export function writeExplorerData(catalog, releasedTests, contributors = { attributions: {}, profiles: [] }) {
  const attributions = new Map(Object.entries(contributors.attributions ?? {}));
  const creditsOf = (id) => {
    const credit = attributions.get(id);
    return credit ? [credit.author, ...(credit.contributors ?? [])].filter(Boolean) : [];
  };
  const taxonomy = catalog.Taxonomy;
  const productNames = new Map(taxonomy.Products.map((p) => [p.Key, p.Name]));
  const featureNames = new Map(taxonomy.Features.map((f) => [`${f.Product}/${f.Key}`, f.Name]));
  const areaNames = new Map(taxonomy.Areas.map((a) => [a.Key, a.Name]));
  const attack = taxonomy.Attack ?? { Version: "", Tactics: [], Techniques: [] };

  const builtIn = catalog.Tests.filter((t) => t.Lifecycle !== "Deprecated").map((t) => ({
    id: t.Id,
    title: t.Title,
    suite: t.Suite,
    pack: "",
    product: t.Product || "",
    feature: t.Feature || "",
    area: t.Area || "",
    severity: t.Severity || "Info",
    impact: t.UserImpact || "",
    cost: t.ImplementationCost || "",
    mitre: (t.Mitre ?? []).filter((m) => m && m !== "None"),
    control: t.Control ?? [],
    authors: creditsOf(t.Id),
    previewOnly: !releasedTests.has(t.Id),
    previewCheck: t.Lifecycle === "Preview",
  }));

  const packs = [];
  const packTests = [];
  for (const pack of catalog.Packs ?? []) {
    const code = pack.Code;
    packs.push({
      id: pack.Id,
      code,
      name: pack.Name,
      description: pack.Description ?? "",
      publisher: pack.Publisher ?? "",
      homepage: pack.Homepage ?? "",
      folder: pack.Folder ?? "",
      module: pack.Module ?? "",
      moduleVersion: pack.ModuleVersion ?? "",
      license: pack.License ?? "",
      source: pack.Source ?? "",
      slug: (pack.Folder ?? pack.Id).split("/").pop(),
      count: pack.Tests.length,
    });
    for (const t of pack.Tests) {
      packTests.push({
        id: t.Id,
        title: t.Title,
        suite: code,
        pack: code,
        product: t.Product || "",
        feature: t.Feature || "",
        area: t.Area || "",
        severity: t.Severity || "Info",
        impact: t.UserImpact || "",
        cost: t.ImplementationCost || "",
        mitre: (t.Mitre ?? []).filter((m) => m && m !== "None"),
        control: [],
        authors: [],
        previewOnly: true,
        previewCheck: false,
        pillar: t.Pillar ?? [],
        category: t.Category ?? "",
        testId: t.TestId ?? "",
        license: t.License ?? [],
        tenantType: t.TenantType ?? [],
        also: t.AlsoCheckedBy ?? [],
      });
    }
  }

  const tests = [...builtIn, ...packTests]
    .map((t) => ({
      ...t,
      productName: productNames.get(t.product) ?? t.product,
      featureName: featureNames.get(`${t.product}/${t.feature}`) ?? t.feature,
      areaName: areaNames.get(t.area) ?? t.area,
    }))
    .sort((a, b) => severityOrder.indexOf(a.severity) - severityOrder.indexOf(b.severity) || a.id.localeCompare(b.id, undefined, { numeric: true }));

  // Each framework by requirement, with the checks that name it in Control.
  const files = loadFrameworkFiles();
  const byRequirement = new Map();
  for (const t of tests) {
    for (const c of t.control) {
      const [key, ...rest] = c.split(":");
      const id = rest.join(":");
      const k = `${key}|${id}`;
      if (!byRequirement.has(k)) byRequirement.set(k, []);
      byRequirement.get(k).push(t.id);
    }
  }
  const frameworks = Object.entries(frameworkConfig)
    .filter(([key]) => files.has(key))
    .map(([key, config]) => {
      const file = files.get(key);
      let requirements = file.requirements.map((r) => ({
        id: r.Id,
        title: r.Title ?? "",
        level: r.Level ?? r.Criticality ?? "",
        // A requirement can sit in several sections (an Essential Eight control under four strategies): it is listed in
        // each, and counted once in the framework's totals.
        sections: [config.section(r)].flat().filter(Boolean).length ? [config.section(r)].flat().filter(Boolean) : ["Other"],
        tests: byRequirement.get(`${key}|${r.Id}`) ?? [],
      }));
      // A long list of controls Maester does not check (the ISM, NIST) lists only those it does.
      if (!config.complete) requirements = requirements.filter((r) => r.tests.length);
      const covered = requirements.filter((r) => r.tests.length).length;
      return {
        key,
        code: config.code,
        label: config.label,
        name: file.name,
        version: file.version,
        url: file.url,
        suite: config.suite,
        complete: config.complete,
        total: requirements.length,
        covered,
        checks: new Set(requirements.flatMap((r) => r.tests)).size,
        requirements,
      };
    });

  const count = (key) => {
    const map = new Map();
    for (const t of tests) if (key(t)) map.set(key(t), (map.get(key(t)) ?? 0) + 1);
    return map;
  };
  const productCounts = count((t) => t.product);
  const featureCounts = count((t) => (t.feature ? `${t.product}/${t.feature}` : ""));
  const products = taxonomy.Products.filter((p) => productCounts.has(p.Key))
    .map((p) => ({
      key: p.Key,
      name: p.Name,
      count: productCounts.get(p.Key),
      features: taxonomy.Features.filter((f) => f.Product === p.Key && featureCounts.has(`${p.Key}/${f.Key}`)).map((f) => ({
        key: f.Key,
        name: f.Name,
        count: featureCounts.get(`${p.Key}/${f.Key}`),
      })),
    }))
    .sort((a, b) => b.count - a.count);
  const areaCounts = count((t) => t.area);
  const areas = taxonomy.Areas.filter((a) => areaCounts.has(a.Key))
    .map((a) => ({ key: a.Key, name: a.Name, count: areaCounts.get(a.Key) }))
    .sort((a, b) => b.count - a.count);

  // The people credited with the checks, most checks first: the nav's author filter.
  const creditCounts = new Map();
  for (const t of tests) for (const id of t.authors) creditCounts.set(id, (creditCounts.get(id) ?? 0) + 1);
  const people = (contributors.profiles ?? [])
    .filter((p) => creditCounts.has(p.id))
    .map((p) => ({ id: p.id, name: p.name, count: creditCounts.get(p.id), avatar: smallAvatar(p.avatar ?? "") }))
    .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));

  const data = {
    $comment: "Written by website/scripts/catalog-explorer.mjs. Do not edit.",
    total: tests.length,
    builtIn: builtIn.length,
    products,
    areas,
    severities: severityOrder.map((s) => ({ key: s, count: tests.filter((t) => t.severity === s).length })).filter((s) => s.count),
    suites: [...count((t) => (t.pack ? "" : t.suite)).entries()].sort((a, b) => b[1] - a[1]).map(([key, n]) => ({ key, count: n })),
    packs,
    people,
    frameworks,
    attack: { version: attack.Version ?? "", tactics: attack.Tactics ?? [], techniques: attack.Techniques ?? [] },
    tests,
  };
  writeFileSync(explorerPath, `${JSON.stringify(data)}\n`);
  return data;
}
