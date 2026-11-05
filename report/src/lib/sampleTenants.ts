// Dev only (?sample=tenants): a merged result of five tenants, the shape Merge-MtMaesterResult writes. Each tenant
// is the sample tenant with some results changed by a fixed hash of tenant and test ID, so the report looks the
// same on every load: one tenant is stronger, one weaker and ran earlier, one did not connect to Exchange Online.
// The sample tenant did not connect to every service; the others did, so their tests for those services ran.

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Raw = Record<string, any>

interface Profile {
  name: string
  id: string
  domain: string
  daysEarlier: number
  fixShare: number // share of failures that pass in this tenant
  breakShare: number // share of passes that fail in this tenant
  noExchange?: boolean
  noPacks?: boolean
}

const PROFILES: Profile[] = [
  { name: "", id: "", domain: "", daysEarlier: 0, fixShare: 0, breakShare: 0 },
  { name: "Fabrikam Inc.", id: "5b1d63a2-0c4e-4b6a-9f0e-2d7a4c1e8b90", domain: "fabrikam.onmicrosoft.com", daysEarlier: 0, fixShare: 0.5, breakShare: 0.03, noExchange: true, noPacks: true },
  { name: "Northwind Traders", id: "a9e04f17-6c2d-4f3b-8e15-7b0c9d2e4a61", domain: "northwindtraders.onmicrosoft.com", daysEarlier: 12, fixShare: 0.08, breakShare: 0.3, noPacks: true },
  { name: "Woodgrove Bank", id: "c3f8b2d0-1a7e-4d59-b6c4-0e9f8a3d2c17", domain: "woodgrovebank.onmicrosoft.com", daysEarlier: 1, fixShare: 0.78, breakShare: 0.02 },
  { name: "Tailwind Traders", id: "e7a1c9b4-3d2f-4e80-a5b6-9c0d1e2f3a48", domain: "tailwindtraders.onmicrosoft.com", daysEarlier: 0, fixShare: 0.25, breakShare: 0.08, noPacks: true },
]

/** A stable number from 0 to 1 for a tenant and a test. */
function chance(seed: string) {
  let h = 2166136261
  for (let i = 0; i < seed.length; i++) h = Math.imul(h ^ seed.charCodeAt(i), 16777619)
  return ((h >>> 0) % 10000) / 10000
}

function shift(iso: string, days: number) {
  const d = new Date(iso)
  d.setDate(d.getDate() - days)
  return d.toISOString()
}

function tenantFrom(base: Raw, p: Profile): Raw {
  if (!p.name) return base
  const tests = (base.Tests as Raw[])
    .filter((t) => !(p.noPacks && t.Package))
    .map((t) => {
      const services: string[] = Array.isArray(t.Service) ? t.Service : []
      if (p.noExchange && services.includes("ExchangeOnline")) {
        return { ...t, Result: "Skipped", ReasonCode: "ServiceNotConnected", ReasonDetail: "Not connected to Exchange Online. Run Connect-Maester -Service ExchangeOnline." }
      }
      if (t.ReasonCode === "ServiceNotConnected") {
        const result = chance(`ran|${p.id}|${t.Id}`) < 0.62 + p.fixShare * 0.3 ? "Passed" : "Failed"
        return { ...t, Result: result, ReasonCode: null, ReasonDetail: null, ResultDetail: { ...t.ResultDetail, TestResult: `Sample data: the test ${result.toLowerCase()} in this tenant.` } }
      }
      // A few tests fail in every tenant, so the rollup has fixes to make once for all of them.
      const sticky = chance(`all|${t.Id}`) < 0.3
      const roll = chance(`${p.id}|${t.Id}`)
      const note = (result: string) => ({ ...t.ResultDetail, TestResult: `Sample data: the test ${result.toLowerCase()} in this tenant.` })
      if (t.Result === "Failed" && !sticky && roll < p.fixShare) return { ...t, Result: "Passed", ReasonCode: null, ResultDetail: note("Passed") }
      if (t.Result === "Passed" && roll < p.breakShare) return { ...t, Result: "Failed", ResultDetail: note("Failed") }
      return t
    })
  const previous: Record<string, string> = {}
  for (const t of tests) {
    if (t.Result !== "Passed" && t.Result !== "Failed") { previous[t.Id] = t.Result; continue }
    previous[t.Id] = chance(`prev|${p.id}|${t.Id}`) < 0.05 ? (t.Result === "Passed" ? "Failed" : "Passed") : t.Result
  }
  const count = (r: string) => tests.filter((t) => t.Result === r).length
  return {
    ...base,
    TenantName: p.name,
    TenantId: p.id,
    Account: `maester@${p.domain}`,
    ExecutedAt: shift(base.ExecutedAt, p.daysEarlier),
    Tests: tests,
    TotalCount: tests.length,
    PassedCount: count("Passed"),
    FailedCount: count("Failed"),
    SkippedCount: count("Skipped"),
    Packs: p.noPacks ? [] : base.Packs,
    Previous: base.Previous ? { ...base.Previous, ExecutedAt: shift(base.Previous.ExecutedAt, p.daysEarlier), File: null, Results: previous } : null,
    ConnectionSummary: p.noExchange && Array.isArray(base.ConnectionSummary)
      ? base.ConnectionSummary.map((c: Raw) => (c.Service === "Exchange Online" ? { ...c, Status: "NotConnected" } : c))
      : base.ConnectionSummary,
  }
}

export function sampleTenants(base: Raw): Raw {
  return { Tenants: PROFILES.map((p) => tenantFrom(base, p)) }
}
