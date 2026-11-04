// The views the sidebar lists. Each is listed only when it has something to show, so a run of one test gets a
// short sidebar and a full run gets every product, framework and pack. A pack's view is built from its rows'
// Fields (ZTA: Pillar, Category), so a new pack needs no code here.

import { frameworkLabel, frameworkTally, tally, type Model, type Row } from "@/lib/model"
import type { IconName } from "./ui"

export interface ViewDef {
  path: string
  group: "Tenants" | "Summary" | "Products" | "Frameworks" | "Packs" | "Reports"
  title: string
  product?: string
  code?: string
  icon?: IconName
  count?: number
  bad?: boolean
}

// A product, framework or pack none of whose tests ran (every one skipped or not run) has nothing to show.
const ran = (rows: Row[]) => rows.some((t) => t.Result !== "Skipped" && t.Result !== "NotRun")

export function buildViews(model: Model, extra: { affectedObjects: boolean; attachments: { title: string; path: string }[]; tenants?: number }): ViewDef[] {
  const views: ViewDef[] = []
  // A merged result of several tenants starts with the page that compares them; the sidebar lists the tenants under it.
  if (extra.tenants && extra.tenants > 1) views.push({ path: "/tenants", group: "Tenants", title: "All tenants", icon: "tenant", count: extra.tenants })
  const focused = model.focused
  // Summary: the pages that cover the whole run, so the action plan, changes and affected objects are never below
  // a long list of products.
  views.push({ path: "/", group: "Summary", title: focused ? (model.rows.length === 1 ? "Result" : "Results") : "Overview", icon: "home" })
  if (model.failing.length >= 2) views.push({ path: "/plan", group: "Summary", title: "Action plan", icon: "fix", count: model.failing.length, bad: true })
  if (!focused) views.push({ path: "/tests", group: "Summary", title: "All tests", icon: "result", count: model.rows.length })
  if (!focused && model.previous && model.changes.newlyFailing.length + model.changes.fixed.length > 0) {
    views.push({ path: "/changes", group: "Summary", title: "Changes since last run", icon: "history", count: model.changes.newlyFailing.length, bad: true })
  }
  if (extra.affectedObjects) views.push({ path: "/affected-objects", group: "Summary", title: "Affected objects", icon: "resource" })
  if (!focused) {
    for (const p of model.products) if (ran(p.rows)) views.push({ path: `/product/${encodeURIComponent(p.key)}`, group: "Products", title: p.name, product: p.key, count: tally(p.rows).Failed, bad: true })
    for (const f of model.frameworks) views.push({ path: `/framework/${encodeURIComponent(f.Key)}`, group: "Frameworks", title: frameworkLabel(f), icon: "framework", count: frameworkTally(model, f).Failed, bad: true })
    if (model.rows.some((t) => t.Mitre.length)) views.push({ path: "/attack", group: "Frameworks", title: "MITRE ATT&CK", icon: "attack" })
  }
  for (const p of model.packs) views.push({ path: `/pack/${encodeURIComponent(p.Id)}`, group: "Packs", title: p.Name, code: p.Code, count: tally(p.rows).Failed, bad: true })
  for (const a of extra.attachments) views.push({ path: a.path, group: "Reports", title: a.title, icon: "report" })
  views.push({ path: "/run", group: "Reports", title: "Run details", icon: "duration" })
  return views
}
