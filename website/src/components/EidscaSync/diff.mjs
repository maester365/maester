// Compares the EIDSCA config published in the Attack & Defense Playbook repository with the copy Maester generates
// its EIDSCA tests from (build/eidsca/EidscaConfig.json) and with Maester's classification of each check
// (build/eidsca/eidsca-test-metadata.json). Used by the EIDSCA sync page and by the weekly sync check
// (website/scripts/check-eidsca-sync.mjs), so both report the same differences.

export const UPSTREAM_URL =
  "https://raw.githubusercontent.com/Cloud-Architekt/AzureAD-Attack-Defense/AADSCAv4/config/EidscaConfig.json";
export const UPSTREAM_PAGE_URL =
  "https://github.com/Cloud-Architekt/AzureAD-Attack-Defense/blob/AADSCAv4/config/EidscaConfig.json";
export const SYNC_PAGE_URL = "https://maester.dev/eidsca-sync";

// Fields of an EIDSCA check and where each one ends up in Maester.
export const CHECK_FIELDS = [
  { field: "CheckId", maester: "Id of the test (Test.EIDSCA.<ID>.ps1)" },
  { field: "DisplayName", maester: "Title, with the ControlName of its area" },
  { field: "Severity", maester: "Severity (Informational becomes Info)" },
  { field: "RecommendedValue", maester: "The value the test passes on; a check without one is not generated" },
  { field: "CurrentValue", maester: "The property the internal function Test-MtEidsca<ID> reads" },
  { field: "DefaultValue", maester: "Documentation, and whether the value is compared as a number" },
  { field: "SkipCondition", maester: "The skip in the test; an Entra ID licence skip becomes License" },
  { field: "SkipReason", maester: "The reason a skipped result shows" },
  { field: "Description", maester: "Test description and Markdown" },
  { field: "Recommendation", maester: "Markdown" },
  { field: "HowToFix", maester: "Remediation section of the Markdown" },
  { field: "PortalDeepLink", maester: "Link to the admin center in the Markdown" },
  { field: "MitreTactic", maester: "MITRE ATT&CK section of the Markdown" },
  { field: "MitreTechnique", maester: "MITRE ATT&CK section of the Markdown (Maester's Mitre attribute is its own)" },
  { field: "MitreMitigation", maester: "MITRE ATT&CK section of the Markdown" },
];

// Fields of an EIDSCA control area that every check in it uses.
export const AREA_FIELDS = [
  { field: "ControlName", maester: "Start of the title of each check" },
  { field: "Description", maester: "Markdown" },
  { field: "Discovery", maester: "Discovery code that skip conditions read" },
  { field: "GraphUri", maester: "Graph request of Test-MtEidsca<ID>" },
  { field: "GraphDocsUrl", maester: "Link to the Graph documentation in the Markdown" },
];

// Attributes Maester keeps in build/eidsca/eidsca-test-metadata.json because the EIDSCA config does not carry them.
export const MAESTER_FIELDS = [
  "Feature",
  "Area",
  "ResourceType",
  "UserImpact",
  "ImplementationCost",
  "Mitre",
  "Control",
  "RelatedProduct",
];

// The checks of an EIDSCA config that Maester collects, keyed by CheckId, with their control area.
export function readChecks(config) {
  const checks = new Map();
  const list = Array.isArray(config) ? config : [];
  for (const category of list) {
    if (category?.CollectedBy !== "Maester") continue;
    for (const area of category.ControlArea ?? []) {
      for (const item of area.Controls ?? []) {
        if (!item?.CheckId) continue;
        checks.set(item.CheckId, { area, item, generated: !isBlank(item.RecommendedValue) });
      }
    }
  }
  return checks;
}

export function readMetadata(metadata) {
  const rows = new Map();
  for (const row of metadata?.TestSettings ?? []) {
    if (row?.Id) rows.set(row.Id, row);
  }
  return rows;
}

function isBlank(value) {
  return value === undefined || value === null || (typeof value === "string" && value.trim() === "");
}

function normalize(value) {
  if (value === undefined || value === null) return "";
  if (Array.isArray(value)) return JSON.stringify(value.map(normalize));
  if (typeof value === "object") return JSON.stringify(value);
  return String(value).replace(/\r\n?/g, "\n").trim();
}

export function formatValue(value) {
  if (Array.isArray(value)) return value.length ? value.join(", ") : "(empty)";
  if (isBlank(value)) return "(empty)";
  return String(value);
}

function compareFields(fields, upstream, repo) {
  const changes = [];
  for (const { field } of fields) {
    if (normalize(upstream?.[field]) !== normalize(repo?.[field])) {
      changes.push({ field, upstream: upstream?.[field], repo: repo?.[field] });
    }
  }
  return changes;
}

// The differences between the upstream config and the repository, and what to do about each.
// Kinds: "new" (generated upstream, not in Maester), "removed" (in Maester, not generated upstream any more),
// "changed" (generated on both sides, with different values) and "metadata" (no Maester classification row).
export function diffEidsca({ upstream, repo, metadata }) {
  const upstreamChecks = readChecks(upstream);
  const repoChecks = readChecks(repo);
  const rows = readMetadata(metadata);
  const differences = [];

  const ids = [...new Set([...upstreamChecks.keys(), ...repoChecks.keys()])].sort();
  for (const id of ids) {
    const up = upstreamChecks.get(id);
    const local = repoChecks.get(id);
    const upGenerated = Boolean(up?.generated);
    const localGenerated = Boolean(local?.generated);
    if (upGenerated && !localGenerated) {
      differences.push({
        id,
        kind: "new",
        title: `${up.area.ControlName} - ${up.item.DisplayName}`,
        action: "Merge the weekly EIDSCA update pull request to add the test" + (rows.has(id) ? "." : ", and add its row to eidsca-test-metadata.json."),
      });
    } else if (!upGenerated && localGenerated) {
      differences.push({
        id,
        kind: "removed",
        title: `${local.area.ControlName} - ${local.item.DisplayName}`,
        action: up
          ? "The check has no recommended value upstream any more. Merge the weekly EIDSCA update pull request to remove the test, or restore the value upstream."
          : "The check is not in the EIDSCA config any more. Merge the weekly EIDSCA update pull request to remove the test, or restore it upstream.",
      });
    } else if (upGenerated && localGenerated) {
      const changes = [
        ...compareFields(AREA_FIELDS, up.area, local.area).map((c) => ({ ...c, field: `Area.${c.field}` })),
        ...compareFields(CHECK_FIELDS, up.item, local.item),
      ];
      if (changes.length > 0) {
        differences.push({
          id,
          kind: "changed",
          title: `${up.area.ControlName} - ${up.item.DisplayName}`,
          changes,
          action: "Merge the weekly EIDSCA update pull request to bring these values into Maester.",
        });
      }
    }
    if (upGenerated && !rows.has(id)) {
      differences.push({
        id,
        kind: "metadata",
        title: `${up.area.ControlName} - ${up.item.DisplayName}`,
        action: "Add a row to build/eidsca/eidsca-test-metadata.json with the Maester classification, chosen with the attribute rubric.",
      });
    }
  }
  return differences;
}

// One row per generated check: what the EIDSCA config gives and what Maester adds.
export function mappingRows({ repo, metadata }) {
  const rows = readMetadata(metadata);
  return [...readChecks(repo).entries()]
    .filter(([, check]) => check.generated)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([id, { area, item }]) => ({
      id,
      title: `${area.ControlName} - ${item.DisplayName}`,
      severity: item.Severity === "Informational" ? "Info" : item.Severity,
      recommendedValue: item.RecommendedValue,
      upstreamMitre: item.MitreTechnique ?? [],
      metadata: rows.get(id) ?? null,
    }));
}

const KIND_LABEL = {
  new: "New upstream",
  removed: "Removed upstream",
  changed: "Changed upstream",
  metadata: "Missing Maester classification",
};

export function kindLabel(kind) {
  return KIND_LABEL[kind] ?? kind;
}

function escapeCell(value) {
  return formatValue(value).replace(/\|/g, "\\|").replace(/\n+/g, " ").slice(0, 300);
}

// The Markdown body of the sync issue.
export function renderIssueMarkdown(differences, { checkedAt, workflowUrl } = {}) {
  const counts = Object.keys(KIND_LABEL)
    .map((kind) => [kind, differences.filter((d) => d.kind === kind).length])
    .filter(([, count]) => count > 0)
    .map(([kind, count]) => `${count} ${kindLabel(kind).toLowerCase()}`)
    .join(", ");
  const lines = [
    `The EIDSCA tests in Maester are not in sync with the [EIDSCA config](${UPSTREAM_PAGE_URL}): ${counts}.`,
    "",
    `See the [EIDSCA sync page](${SYNC_PAGE_URL}) for how the EIDSCA config maps to Maester and to compare the two live.`,
    "",
    "Most differences are cleared by merging the weekly `chore: update EIDSCA tests from the EIDSCA config` pull request. This issue is updated by the weekly check while differences remain, and closed when there are none.",
    "",
    "| Check | Difference | Details | What to do |",
    "| --- | --- | --- | --- |",
  ];
  for (const d of differences) {
    const details = d.changes
      ? d.changes.map((c) => `**${c.field}**: \`${escapeCell(c.repo)}\` → \`${escapeCell(c.upstream)}\``).join("<br>")
      : escapeCell(d.title);
    lines.push(`| ${d.id} | ${kindLabel(d.kind)} | ${details} | ${d.action} |`);
  }
  lines.push("");
  const footer = [checkedAt ? `Last checked ${checkedAt}` : null, workflowUrl ? `by [this run](${workflowUrl})` : null].filter(Boolean).join(" ");
  if (footer) lines.push(`_${footer}._`);
  return lines.join("\n") + "\n";
}
