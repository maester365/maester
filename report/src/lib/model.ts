// The report's view of one result: rows with every field the views use, and what the views compute from them
// (counts, ranking, framework coverage, changes since the last run, packs). A Maester 2.x result and the rows of
// Pester-format tests lack most 3.0 fields; every helper copes with a missing value, and the views that need a
// field hide when no row has it (see views.tsx).

import { getReportAttachments, type ReportAttachment } from "@/lib/reportAttachments"

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Raw = Record<string, any>

export const RESULTS = ["Passed", "Failed", "Investigate", "Error", "Skipped", "NotRun"] as const
export type ResultName = (typeof RESULTS)[number]
export const RESULT_LABEL: Record<string, string> = { Passed: "Passed", Failed: "Failed", Investigate: "Investigate", Error: "Error", Skipped: "Skipped", NotRun: "Not run" }
// The order a list of tests is sorted in: what needs action first.
export const RESULT_ORDER = ["Failed", "Error", "Investigate", "Passed", "Skipped", "NotRun"]
export const SEVERITIES = ["Critical", "High", "Medium", "Low", "Info"]
const SEVERITY_WEIGHT: Record<string, number> = { Critical: 4, High: 3, Medium: 2, Low: 1, Info: 0 }
const LEVEL_EASE: Record<string, number> = { Low: 2, Medium: 1, High: 0 }

// What each severity means, from the attribute rubric (website/docs/writing-tests/attribute-rubric.md).
export const SEVERITY_MEANING: Record<string, string> = {
  Critical: "An attacker can take over the tenant or a privileged identity now.",
  High: "Common attacks such as phishing or password spray can use it.",
  Medium: "A second line of defence is missing, or the exposure is limited.",
  Low: "Hygiene with a small effect on its own.",
  Info: "A fact to review. Not scored.",
}

// What an attacker could do when the tests of these areas fail, in plain words.
export const OUTCOMES: { title: string; short: string; text: string; areas: string[] }[] = [
  { title: "Sign in as your users", short: "Sign-in", text: "Sign-in rules decide whether a stolen or guessed password is enough.", areas: ["authentication", "access-control"] },
  { title: "Take over an admin", short: "Admins", text: "Too many or weakly protected admins turn one breach into full control.", areas: ["privileged-access"] },
  { title: "Get in through apps and guests", short: "Apps and guests", text: "Apps, consent and guest access are ways in that skip the sign-in rules.", areas: ["applications", "external-access"] },
  { title: "Phish users and hide in mail", short: "Mail", text: "Mail settings decide what reaches users and where an attacker can hide.", areas: ["email-protection"] },
  { title: "Take data out", short: "Data", text: "Sharing and data protection decide what can leave the tenant.", areas: ["data-protection"] },
  { title: "Work through devices", short: "Devices", text: "Weakly configured devices give an attacker a foothold.", areas: ["devices"] },
  { title: "Go unnoticed", short: "Detection", text: "Without logs and alerts an attack is found late, or not at all.", areas: ["logging-and-detection"] },
  { title: "Exploit weak foundations", short: "Foundations", text: "Tenant-wide settings that every other control relies on.", areas: ["infrastructure", "identity-lifecycle", "engineering-systems", "ai"] },
]

export const TACTICS: [string, string][] = [
  ["TA0043", "Reconnaissance"], ["TA0042", "Resource Development"], ["TA0001", "Initial Access"], ["TA0002", "Execution"],
  ["TA0003", "Persistence"], ["TA0004", "Privilege Escalation"], ["TA0005", "Defense Evasion"], ["TA0006", "Credential Access"],
  ["TA0007", "Discovery"], ["TA0008", "Lateral Movement"], ["TA0009", "Collection"], ["TA0011", "Command and Control"],
  ["TA0010", "Exfiltration"], ["TA0040", "Impact"],
]

// Short names for the frameworks Maester ships; any other framework shows its own name.
export const FRAMEWORK_LABEL: Record<string, string> = {
  "cis-m365": "CIS Microsoft 365", "cis-github": "CIS GitHub", "cisa-scuba": "CISA SCuBA",
  "essential-eight": "Essential Eight", ism: "ASD ISM", "nist-800-53-r5": "NIST SP 800-53",
}

// The order frameworks are listed in everywhere: NIST, CISA, CIS, then ASD's ISM and Essential Eight, then any other.
const FRAMEWORK_ORDER = ["nist-800-53-r5", "cisa-scuba", "cis-m365", "cis-github", "ism", "essential-eight"]
export const frameworkRank = (key: string) => (FRAMEWORK_ORDER.indexOf(key) + 1 || FRAMEWORK_ORDER.length + 1)

// Why a test did not run, as a heading and what to do about it. Codes: website/docs/configuration/applicability.md.
export const REASONS: Record<string, [string, string]> = {
  ServiceNotConnected: ["Service not connected", "Connect to the service and run again."],
  ServiceNotRegistered: ["Service not registered", "The test needs a service no connector provides."],
  LicenseNotFound: ["Licence not in the tenant", "These tests need a licence the tenant does not have."],
  TenantTypeMismatch: ["Not for this kind of tenant", "These tests apply to another tenant type."],
  CloudMismatch: ["Not for this cloud", "These tests apply to another Microsoft cloud."],
  PlatformMismatch: ["Not for this platform", "These tests need another operating system."],
  NotApplicable: ["Does not apply", "The tenant has nothing for these tests to check."],
  TestSkipped: ["The test skipped itself", "Each test says why."],
  NoInstances: ["Nothing to check", "The family found no items to test."],
  NoResult: ["No result", "The test returned no verdict."],
  LongRunning: ["Long-running, not selected", "Run with -IncludeLongRunning to include them."],
  Preview: ["Preview, not selected", "Run with -IncludePreview to include them."],
  DisabledByConfig: ["Turned off in the config", "The Maester config turns these tests off."],
  ExcludedByTag: ["Excluded by tag", "The run's tag filter left these out."],
  ExcludedById: ["Excluded by ID", "The run named these tests to leave out."],
  ExcludedByProduct: ["Excluded by product", "The run's product filter left these out."],
  NotSelected: ["Not selected", "The run's selection left these out."],
  NotListed: ["Not listed", "The config lists the tests to run, and not these."],
  OptInServiceNotConnected: ["Opt-in service not connected", "Connect the service to run these tests."],
  PackUnavailable: ["Pack not available", "The pack could not be found."],
  PackNotAllowed: ["Pack not allowed", "The pack policy does not allow this pack."],
  PackBlocked: ["Pack blocked", "The pack is on the block list."],
  DryRun: ["Dry run", "Nothing ran."],
  TestError: ["The test failed to run", "Read the error on each test."],
  Timeout: ["The test timed out", "Raise the timeout in the Maester config or run the test alone."],
  InvalidReturn: ["The test returned no verdict", "The test must return $true or $false."],
}

const SERVICE_NAME: Record<string, string> = {
  Graph: "Microsoft Graph", ExchangeOnline: "Exchange Online", SecurityCompliance: "Security & Compliance", Teams: "Microsoft Teams",
  SharePointOnline: "SharePoint Online", Azure: "Azure", AzureDevOps: "Azure DevOps", GitHub: "GitHub", Dataverse: "Dataverse", ActiveDirectory: "Active Directory",
}

export interface Row {
  Id: string
  Title: string
  Result: string
  Severity: string
  Product: string | null
  RelatedProduct: string[]
  Feature: string | null
  Area: string | null
  ResourceType: string | null
  UserImpact: string | null
  ImplementationCost: string | null
  Mitre: string[]
  Control: string[]
  Benchmark: Raw | null
  Lifecycle: string | null
  ReplacedBy: string | null
  Service: string[]
  License: string[]
  Permission: string[]
  Source: string | null
  Suite: string | null
  Format: string | null
  Duration: string | null
  HelpUrl: string | null
  Tag: string[]
  ReasonCode: string | null
  ReasonDetail: string | null
  ParentId: string | null
  Package: Raw | null
  Fields: Record<string, string | string[]> | null
  ShimOf: string | null
  Parameters: { Name: string; Value: unknown; Source?: string }[]
  Description: string
  Detail: string
  raw: Raw
}

export interface Tally {
  total: number
  Passed: number
  Failed: number
  Investigate: number
  Error: number
  Skipped: number
  NotRun: number
  scored: number
  rate: number | null
}

export interface Framework {
  Key: string
  Name: string
  Version: string | null
  Complete: boolean
  Requirements: Raw[]
}

export interface Pack {
  Id: string
  Code: string
  Name: string
  Description: string | null
  Version: string | null
  Publisher: string | null
  BuiltIn: boolean
  Homepage: string | null
  Risk: string | null
  Status: string
  Reason: string | null
}

const text = (value: unknown) => (value === null || value === undefined ? "" : String(value))
// PowerShell writes a one-item list as a single value.
const list = (value: unknown): string[] => (value === null || value === undefined ? [] : (Array.isArray(value) ? value : [value]).map(text).filter(Boolean))

function normalize(t: Raw): Row {
  const detail = t.ResultDetail || {}
  const name = text(t.Name)
  const id = text(t.Id) || (name.match(/^([^\s:]+):/) || [])[1] || name
  return {
    Id: id,
    Title: text(t.Title) || name.replace(/^[^\s:]+:\s*/, ""),
    Result: text(t.Result) || "NotRun",
    Severity: text(t.Severity || detail.Severity),
    Product: t.Product ? text(t.Product) : null,
    RelatedProduct: list(t.RelatedProduct),
    Feature: t.Feature ? text(t.Feature) : null,
    Area: t.Area ? text(t.Area) : null,
    ResourceType: t.ResourceType ? text(t.ResourceType) : null,
    UserImpact: t.UserImpact ? text(t.UserImpact) : null,
    ImplementationCost: t.ImplementationCost ? text(t.ImplementationCost) : null,
    Mitre: list(t.Mitre).filter((m) => m !== "None"),
    Control: list(t.Control),
    Benchmark: t.Benchmark && t.Benchmark.Framework ? t.Benchmark : null,
    Lifecycle: t.Lifecycle ? text(t.Lifecycle) : null,
    ReplacedBy: t.ReplacedBy ? text(t.ReplacedBy) : null,
    Service: list(t.Service),
    License: list(t.License),
    Permission: list(t.Permission),
    Source: t.Source ? text(t.Source) : null,
    Suite: t.Suite ? text(t.Suite) : null,
    Format: t.Format ? text(t.Format) : null,
    Duration: t.Duration ? text(t.Duration) : null,
    HelpUrl: t.HelpUrl ? text(t.HelpUrl) : null,
    Tag: list(t.Tag),
    ReasonCode: t.ReasonCode ? text(t.ReasonCode) : null,
    ReasonDetail: t.ReasonDetail ? text(t.ReasonDetail) : t.Result === "Skipped" || t.Result === "NotRun" ? text(detail.SkippedReason) || null : null,
    ParentId: t.ParentId ? text(t.ParentId) : null,
    Package: t.Package && t.Package.Id ? t.Package : null,
    Fields: t.Fields && typeof t.Fields === "object" ? t.Fields : null,
    ShimOf: t.ShimOf ? text(t.ShimOf) : null,
    Parameters: Array.isArray(t.Parameters) ? t.Parameters : [],
    Description: text(detail.TestDescription),
    Detail: text(detail.TestResult),
    raw: t,
  }
}

export function tally(rows: Row[]): Tally {
  const c: Tally = { total: rows.length, Passed: 0, Failed: 0, Investigate: 0, Error: 0, Skipped: 0, NotRun: 0, scored: 0, rate: null }
  let passed = 0
  for (const t of rows) {
    if (t.Result in c) (c as unknown as Record<string, number>)[t.Result]++
    // Info tests make no risk judgement and are left out of scores.
    if (t.Severity !== "Info" && (t.Result === "Passed" || t.Result === "Failed")) {
      c.scored++
      if (t.Result === "Passed") passed++
    }
  }
  c.rate = c.scored ? Math.round((passed / c.scored) * 100) : null
  return c
}

/** Severity first; within a severity, fixes that cost little and that users won't notice. */
export function priority(t: Row) {
  return (SEVERITY_WEIGHT[t.Severity] ?? 2) * 4 + (LEVEL_EASE[t.UserImpact || ""] ?? 1) * 1.5 + (LEVEL_EASE[t.ImplementationCost || ""] ?? 1) * 1.5 +
    Math.min(t.Mitre.length, 3) * 0.3 + (t.Control.length + (t.Benchmark ? 1 : 0)) * 0.2
}
export const isQuickWin = (t: Row) => t.UserImpact === "Low" && t.ImplementationCost === "Low" && (SEVERITY_WEIGHT[t.Severity] ?? 0) >= 2
export const severityWeight = (s: string) => SEVERITY_WEIGHT[s] ?? 2
export const outcomeOf = (t: Row) => OUTCOMES.find((o) => t.Area && o.areas.includes(t.Area))

/** The guide's explanation, and its remediation section when it has one. */
export function splitGuide(source: string) {
  const match = source.match(/^#{2,6}\s*(Remediation[^\n]*|How to fix[^\n]*|Investigation steps[^\n]*)$/im)
  if (!match || match.index === undefined) return { about: source.trim(), fix: "" }
  return { about: source.slice(0, match.index).trim(), fix: source.slice(match.index).trim() }
}

/** Framework requirements a test names: its Benchmark first, then its other Control values. */
export function requirementsOf(t: Row): [string, string][] {
  const out: [string, string][] = []
  if (t.Benchmark) out.push([text(t.Benchmark.Framework), text(t.Benchmark.Requirement)])
  for (const c of t.Control) {
    const i = c.indexOf(":")
    if (i < 1) continue
    const key = c.slice(0, i), id = c.slice(i + 1)
    if (!out.some(([k, r]) => k === key && r === id)) out.push([key, id])
  }
  return out.sort((a, b) => frameworkRank(a[0]) - frameworkRank(b[0]))
}

/** The command that connects the service a skipped test needs. */
export function fixCommand(t: Row): string {
  switch (t.ReasonCode) {
    case "ServiceNotConnected":
    case "OptInServiceNotConnected": {
      const service = t.Service.find((s) => s !== "Graph") || t.Service[0] || "All"
      return `Connect-Maester -Service ${service}`
    }
    case "LongRunning": return "Invoke-Maester -IncludeLongRunning"
    case "Preview": return "Invoke-Maester -IncludePreview"
    case "TestError": case "Timeout": return `Invoke-Maester -TestId ${t.Id} -Verbose`
    default: return ""
  }
}
export const serviceName = (key: string) => SERVICE_NAME[key] || key

export interface Model {
  result: Raw
  rows: Row[]
  byId: Map<string, Row>
  all: Tally
  failing: Row[]
  ranked: Row[]
  // Taxonomy display names.
  productName: (key: string | null) => string
  featureName: (t: Row) => string
  areaName: (key: string | null) => string
  technique: (id: string) => { Id: string; Name: string; Tactics: string[] }
  attackVersion: string | null
  // Products with rows of their own, in taxonomy order. Pack rows whose product the taxonomy does not know stay in their pack.
  products: { key: string; name: string; rows: Row[] }[]
  frameworks: Framework[]
  requirementTests: (key: string, id: string) => Row[]
  packs: (Pack & { rows: Row[] })[]
  packOf: (t: Row) => (Pack & { rows: Row[] }) | undefined
  previous: { ExecutedAt: string; File: string | null; Results: Record<string, string> } | null
  changes: { newlyFailing: Row[]; fixed: Row[]; added: Row[] }
  attachments: ReportAttachment[]
  hasAttributes: boolean
  // A run of one to three tests is shown as the tests themselves.
  focused: boolean
}

export function requirementStatus(rows: Row[] | undefined): string {
  if (!rows || !rows.length) return "none"
  if (rows.some((t) => t.Result === "Failed")) return "Failed"
  if (rows.some((t) => t.Result === "Passed")) return "Passed"
  if (rows.some((t) => t.Result === "Investigate" || t.Result === "Error")) return "Investigate"
  return "Skipped"
}

export function buildModel(result: Raw): Model {
  const rows: Row[] = (Array.isArray(result?.Tests) ? result.Tests : []).map(normalize)
  const byId = new Map(rows.map((t) => [t.Id, t]))
  const taxonomy = result?.Taxonomy || {}
  const productNames = new Map<string, string>((taxonomy.Products || []).map((p: Raw) => [p.Key, p.Name || p.Key]))
  const featureNames = new Map<string, string>((taxonomy.Features || []).map((f: Raw) => [`${f.Product}/${f.Key}`, f.Name || f.Key]))
  const areaNames = new Map<string, string>((taxonomy.Areas || []).map((a: Raw) => [a.Key, a.Name || a.Key]))
  const techniques = new Map<string, Raw>((taxonomy.Attack?.Techniques || []).map((t: Raw) => [t.Id, t]))
  const failing = rows.filter((t) => t.Result === "Failed")
  const hasAttributes = rows.some((t) => t.Product || t.Area || t.Benchmark)
  // A 2.x result has no Product: its Block (the Describe name, such as Entra ID) stands in for it.
  if (!hasAttributes) for (const t of rows) if (!t.Product && t.raw.Block) t.Product = text(t.raw.Block)

  // Packs: the result's list when it has one, else what the rows say.
  const packMap = new Map<string, Pack & { rows: Row[] }>()
  for (const p of Array.isArray(result?.Packs) ? result.Packs : []) {
    packMap.set(p.Id, { Id: p.Id, Code: text(p.Code) || p.Id, Name: text(p.Name) || p.Id, Description: p.Description ?? null, Version: p.Version ?? null, Publisher: p.Publisher ?? null, BuiltIn: !!p.BuiltIn, Homepage: p.Homepage ?? null, Risk: p.Risk ?? null, Status: text(p.Status) || "Ready", Reason: p.Reason ?? null, rows: [] })
  }
  for (const t of rows) {
    if (!t.Package) continue
    const id = text(t.Package.Id)
    if (!packMap.has(id)) {
      const code = text(t.Suite) || id
      packMap.set(id, { Id: id, Code: code, Name: text(t.Package.Name) || id, Description: null, Version: t.Package.Version ?? null, Publisher: t.Package.Publisher ?? null, BuiltIn: !!t.Package.BuiltIn, Homepage: null, Risk: null, Status: "Ready", Reason: null, rows: [] })
    }
    packMap.get(id)!.rows.push(t)
  }
  const packs = [...packMap.values()]

  // Products: taxonomy products in their order, then any other product value of a test that is not from a pack.
  const productRows = new Map<string, Row[]>()
  for (const t of rows) {
    const key = t.Product
    if (!key || (t.Package && !productNames.has(key))) continue
    if (!productRows.has(key)) productRows.set(key, [])
    productRows.get(key)!.push(t)
  }
  const order = [...productNames.keys()]
  const products = [...productRows.entries()]
    .sort((a, b) => (order.indexOf(a[0]) + 1 || 999) - (order.indexOf(b[0]) + 1 || 999))
    .map(([key, list]) => ({ key, name: productNames.get(key) || key, rows: list }))

  // Frameworks: the catalogue in the result when it has one, else the requirements the rows name.
  const index = new Map<string, Row[]>()
  for (const t of rows) for (const [k, id] of requirementsOf(t)) {
    const key = `${k}|${id}`
    if (!index.has(key)) index.set(key, [])
    index.get(key)!.push(t)
  }
  let frameworks: Framework[] = (Array.isArray(result?.Frameworks) ? result.Frameworks : []).map((f: Raw) => ({
    Key: f.Key, Name: text(f.Name) || f.Key, Version: f.Version ?? null, Complete: !!f.Complete, Requirements: Array.isArray(f.Requirements) ? f.Requirements : [],
  }))
  if (!frameworks.length) {
    const keys = new Map<string, Set<string>>()
    for (const key of index.keys()) { const [k, id] = key.split("|"); if (!keys.has(k)) keys.set(k, new Set()); keys.get(k)!.add(id) }
    frameworks = [...keys.entries()].map(([k, ids]) => ({ Key: k, Name: FRAMEWORK_LABEL[k] || k, Version: null, Complete: false, Requirements: [...ids].sort().map((Id) => ({ Id })) }))
  }
  // Only frameworks a test of this run maps to.
  frameworks = frameworks.filter((f) => f.Requirements.some((r) => index.has(`${f.Key}|${r.Id}`))).sort((a, b) => frameworkRank(a.Key) - frameworkRank(b.Key))

  const previous = result?.Previous && result.Previous.Results ? result.Previous : null
  const changes = { newlyFailing: [] as Row[], fixed: [] as Row[], added: [] as Row[] }
  if (previous) {
    for (const t of rows) {
      const before = previous.Results[t.Id]
      if (!before) { if (t.Result === "Passed" || t.Result === "Failed") changes.added.push(t); continue }
      if (t.Result === "Failed" && before === "Passed") changes.newlyFailing.push(t)
      if (t.Result === "Passed" && before === "Failed") changes.fixed.push(t)
    }
  }

  return {
    result,
    rows,
    byId,
    all: tally(rows),
    failing,
    ranked: [...failing].sort((a, b) => priority(b) - priority(a)),
    productName: (key) => (key ? productNames.get(key) || key : "Custom tests"),
    featureName: (t) => (t.Feature ? featureNames.get(`${t.Product}/${t.Feature}`) || t.Feature.replace(/-/g, " ") : ""),
    areaName: (key) => (key ? areaNames.get(key) || key : ""),
    technique: (id) => { const t = techniques.get(id); return { Id: id, Name: text(t?.Name) || id, Tactics: list(t?.Tactics) } },
    attackVersion: taxonomy.Attack?.Version ?? null,
    products,
    frameworks,
    requirementTests: (key, id) => index.get(`${key}|${id}`) || [],
    packs,
    packOf: (t) => (t.Package ? packMap.get(text(t.Package.Id)) : undefined),
    previous,
    changes,
    attachments: getReportAttachments(result),
    hasAttributes,
    focused: rows.length > 0 && rows.length <= 3,
  }
}

export function frameworkTally(model: Model, f: Framework, requirements = f.Requirements) {
  const c = { total: requirements.length, Passed: 0, Failed: 0, Investigate: 0, Skipped: 0, none: 0 }
  for (const r of requirements) (c as Record<string, number>)[requirementStatus(model.requirementTests(f.Key, r.Id))]++
  return c
}

/** Tests in the order lists show them: failures first, then by severity and ID. */
export function sortTests(rows: Row[]) {
  return [...rows].sort((a, b) => RESULT_ORDER.indexOf(a.Result) - RESULT_ORDER.indexOf(b.Result) || severityWeight(b.Severity) - severityWeight(a.Severity) || a.Id.localeCompare(b.Id, undefined, { numeric: true }))
}

export const frameworkLabel = (f: { Key: string; Name: string }) => FRAMEWORK_LABEL[f.Key] || f.Name

/** The Maester version that wrote the result. CurrentVersion is a [version] object in 2.x results, so a 3.x result
 * also carries it as the string CatalogVersion. */
export function maesterVersion(result: Raw): string {
  const v = result?.CatalogVersion || result?.CurrentVersion
  if (!v) return ""
  if (typeof v !== "object") return String(v)
  return [v.Major, v.Minor, v.Build, v.Revision].filter((n) => typeof n === "number" && n >= 0).join(".")
}
