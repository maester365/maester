// Figures the overview draws from a model: the trend over earlier runs, each framework's share of requirements met
// now and in the previous run, the posture grid of frameworks by attacker outcome, and the objects the run checked.

import { OUTCOMES, requirementStatus, requirementsOf, tally, type Framework, type Model, type Row } from "@/lib/model"
import { getAffectedObjectTypeInfo } from "@/lib/affectedObjectTypes"

export interface RunPoint { at: string; total: number; passed: number; failed: number; rate: number | null; current: boolean }

/** Earlier runs from Previous.History and this run, oldest first. */
export function runHistory(model: Model): RunPoint[] {
  const earlier = Array.isArray(model.result?.Previous?.History) ? model.result.Previous.History : []
  const points: RunPoint[] = earlier.map((h: Record<string, number | string>) => {
    const passed = Number(h.Passed) || 0
    const failed = Number(h.Failed) || 0
    return { at: String(h.ExecutedAt), total: Number(h.Total) || 0, passed, failed, rate: passed + failed ? Math.round((passed / (passed + failed)) * 100) : null, current: false }
  })
  points.sort((a, b) => new Date(a.at).getTime() - new Date(b.at).getTime())
  // The trend counts every Passed and Failed row, as the earlier runs' counts do, so this run uses the same rule.
  const passed = model.rows.filter((t) => t.Result === "Passed").length
  const failed = model.rows.filter((t) => t.Result === "Failed").length
  points.push({ at: String(model.result.ExecutedAt), total: model.rows.length, passed, failed, rate: passed + failed ? Math.round((passed / (passed + failed)) * 100) : null, current: true })
  return points
}

/** Requirements met of those with a passed or failed test, now or (with previous) in the previous run. */
export function frameworkMet(model: Model, f: Framework, previous = false) {
  let met = 0
  let tested = 0
  const before = model.previous?.Results || {}
  for (const r of f.Requirements) {
    let rows = model.requirementTests(f.Key, r.Id)
    if (previous) rows = rows.filter((t) => before[t.Id]).map((t) => ({ ...t, Result: before[t.Id] }))
    const status = requirementStatus(rows)
    if (status === "Passed" || status === "Failed") tested++
    if (status === "Passed") met++
  }
  return { met, tested, rate: tested ? Math.round((met / tested) * 100) : null }
}

export interface PostureCell { failed: number; total: number; rate: number | null }

/** For each framework, the tests that map to it in each attacker outcome. */
export function postureGrid(model: Model) {
  return model.frameworks.map((f) => {
    const rows = model.rows.filter((t) => requirementsOf(t).some(([k]) => k === f.Key))
    const cells: PostureCell[] = OUTCOMES.map((o) => {
      const c = tally(rows.filter((t) => t.Area && o.areas.includes(t.Area)))
      return { failed: c.Failed, total: c.total, rate: c.scored ? c.rate : null }
    })
    return { framework: f, cells, now: frameworkMet(model, f), before: model.previous ? frameworkMet(model, f, true) : null }
  })
}

// The feature icon that stands for an object type on the overview.
const TYPE_ICON: Record<string, string> = {
  ConditionalAccessPolicy: "conditional-access", User: "users", Group: "groups", ServicePrincipal: "enterprise-applications",
  AppRegistration: "app-registrations", DirectoryRole: "entra-identity-roles-and-administrators", AccessPackage: "identity-governance",
  AccessPackageCatalog: "identity-governance", TransportRule: "mail-alert", SharingPolicy: "calendar-month",
}

/** The objects tests named (AffectedObjects with Referenced), by type, and how many are named by a failing test. */
export function objectsChecked(model: Model) {
  const records = Array.isArray(model.result?.AffectedObjects) ? model.result.AffectedObjects : []
  const failing = new Set(model.rows.filter((t: Row) => t.Result === "Failed").map((t) => t.Id))
  const types = new Map<string, { type: string; name: string; icon: string | null; count: number; failing: number }>()
  let reads = 0
  for (const r of records) {
    if (r.Referenced === false) { reads++; continue }
    const key = `${r.System}|${r.Type}`
    if (!types.has(key)) types.set(key, { type: r.Type, name: getAffectedObjectTypeInfo(r.System, r.Type).name, icon: TYPE_ICON[r.Type] || null, count: 0, failing: 0 })
    const g = types.get(key)!
    g.count++
    if ((r.Tests || []).some((id: string) => failing.has(id))) g.failing++
  }
  return { types: [...types.values()].sort((a, b) => b.count - a.count), reads, total: records.length }
}
