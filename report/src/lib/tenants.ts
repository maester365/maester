// Comparing the tenants of a merged result (Merge-MtMaesterResult): each test's result in every tenant, which
// tests fail in most tenants (fix once, roll out everywhere) and which fail in one tenant only.

import { priority, type Model, type Row } from "@/lib/model"

export const tenantName = (model: Model, index: number) => String(model.result.TenantName || model.result.TenantId || `Tenant ${index + 1}`).replace(/\.$/, "")

export function tenantInitials(name: string) {
  const words = name.replace(/[^\p{L}\p{N} ]/gu, "").split(/\s+/).filter((w) => w && !/^(inc|ltd|llc|corp|co|the)$/i.test(w))
  return (words.length > 1 ? words[0][0] + words[1][0] : (words[0] || "?").slice(0, 2)).toUpperCase()
}

export interface CrossTest {
  id: string
  test: Row
  results: (Row | undefined)[]
  failed: number
  passed: number
  ran: number
}

export function crossTests(models: Model[]): CrossTest[] {
  const map = new Map<string, CrossTest>()
  models.forEach((m, i) => {
    for (const t of m.rows) {
      if (!map.has(t.Id)) map.set(t.Id, { id: t.Id, test: t, results: models.map(() => undefined), failed: 0, passed: 0, ran: 0 })
      const c = map.get(t.Id)!
      c.results[i] = t
      if (t.Result === "Failed") c.failed++
      if (t.Result === "Passed") c.passed++
      if (t.Result === "Passed" || t.Result === "Failed") c.ran++
    }
  })
  return [...map.values()]
}

/** Failing in at least two tenants and in most of the tenants it ran in. */
export const failingInMost = (all: CrossTest[]) =>
  all.filter((c) => c.failed >= 2 && c.failed * 2 >= c.ran).sort((a, b) => b.failed - a.failed || priority(b.test) - priority(a.test))

/** Failing in one tenant while at least two others pass: usually a setting someone changed there. */
export const failingInOne = (all: CrossTest[]) =>
  all.filter((c) => c.failed === 1 && c.passed >= 2).sort((a, b) => priority(b.test) - priority(a.test))

/** A pass rate in five bands, for the heat cells. */
export const band = (rate: number | null) => (rate === null ? "none" : rate >= 90 ? "4" : rate >= 75 ? "3" : rate >= 60 ? "2" : rate >= 40 ? "1" : "0")
