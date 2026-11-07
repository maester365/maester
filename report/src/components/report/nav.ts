// The report's menu. The home menu lists the pages that cover the whole run and one row for each hub: Products,
// Frameworks and each pack. A hub has its own menu, a tree of any depth, shown beside the home menu's icon rail.
// The URL decides what is selected, so a link opens the same menu wherever it is followed.
//
// A pack's menu comes from its manifest (Report.Navigation, lib/packNav.ts); a pack that declares none gets an
// overview, one page per value of its tests' first field, its reports and an About page. Every entry opens one of
// the report's built-in views: a pack never brings code into the report.

import { frameworkLabel, frameworkTally, tally, type Model, type Pack, type Row } from "@/lib/model"
import { fieldValues, slug, type NavEntry } from "@/lib/packNav"
import { getAttachmentPath, getReportAttachments, getTestAttachments, type ReportAttachment } from "@/lib/reportAttachments"
import { WORKSHOP_ATTACHMENT, type Plan } from "@/lib/zeroTrust"
import type { IconName } from "./ui"

/** What a pack page shows. The page reads its rows and data from the model with these. */
export interface PackPageDef {
  view: "pack" | "tests" | "plan" | "guide" | "about"
  packId: string
  title: string
  result?: string
  filter?: Record<string, string[]>
  /** The fields the page's table groups by: the levels below this page. */
  groupBy?: string[]
  attachment?: string
  /** The plan's own link; its pillars, areas and swimlanes are below it. */
  planPath?: string
  pillar?: string
  area?: string
  /** The swimlane, as its name in a link. */
  lane?: string
  page?: string
}

export interface NavItem {
  key: string
  title: string
  /** The page the row opens. A row without one only opens and closes its items. */
  path?: string
  icon?: IconName
  product?: string
  code?: string
  count?: number
  bad?: boolean
  /** Done of total, drawn as a small bar (the Zero Trust plan's rows). */
  prog?: [number, number]
  /** A heading in a hub menu; its items are rows at the same depth. */
  section?: boolean
  items?: NavItem[]
  /** A home row that opens this hub. */
  hub?: string
  page?: PackPageDef
}

export interface Hub {
  key: string
  title: string
  sub: string
  icon?: IconName
  code?: string
  path: string
  count?: number
  bad?: boolean
  items: NavItem[]
}

export interface HomeGroup {
  key: string
  title?: string
  items: NavItem[]
  /** Draws the tenants of a merged result under the group. */
  tenants?: boolean
  /** Draws the link to add a pack. */
  addPack?: boolean
}

export interface NavModel {
  home: HomeGroup[]
  hubs: Hub[]
}

export interface Located {
  item: NavItem | null
  hub: Hub | null
  /** The rows above the item in its hub menu, outermost first; headings are left out. */
  trail: NavItem[]
}

// A product, framework or pack none of whose tests ran (every one skipped or not run) has nothing to show.
const ran = (rows: Row[]) => rows.some((t) => t.Result !== "Skipped" && t.Result !== "NotRun")
const failed = (rows: Row[]) => tally(rows).Failed

/** The part of a pack's links after /pack/: its code in lower case, or its ID. */
export const packSlug = (p: Pick<Pack, "Id" | "Code">) => (p.Code && p.Code !== p.Id ? p.Code.toLowerCase() : p.Id)

export interface NavExtras {
  affectedObjects: boolean
  tenants: number
  /** Plans read so far, by attachment name. A plan entry lists its pillars once its plan is here. */
  plans: Map<string, Plan>
}

export function buildNav(model: Model, extra: NavExtras): NavModel {
  const home: HomeGroup[] = []
  const hubs: Hub[] = []
  const focused = model.focused
  if (extra.tenants > 1) home.push({ key: "tenants", title: "Tenants", items: [{ key: "/tenants", title: "All tenants", path: "/tenants", icon: "tenant", count: extra.tenants }], tenants: true })

  // The pages that cover the whole run.
  const summary: NavItem[] = [{ key: "/", title: focused ? (model.rows.length === 1 ? "Result" : "Results") : "Overview", path: "/", icon: "home" }]
  if (model.failing.length >= 2 || (!focused && model.path)) summary.push({ key: "/plan", title: "Action plan", path: "/plan", icon: "fix", count: model.failing.length, bad: true })
  if (!focused && model.previous && model.changes.newlyFailing.length + model.changes.fixed.length > 0) {
    summary.push({ key: "/changes", title: "Changes since last run", path: "/changes", icon: "history", count: model.changes.newlyFailing.length, bad: true })
  }
  if (!focused) summary.push({ key: "/tests", title: "All tests", path: "/tests", icon: "result", count: model.rows.length })
  if (extra.affectedObjects) summary.push({ key: "/affected-objects", title: "Affected objects", path: "/affected-objects", icon: "resource" })
  home.push({ key: "summary", items: summary })

  if (!focused) {
    const products = model.products.filter((p) => ran(p.rows))
    const productItems: NavItem[] = products.map((p) => ({ key: `/product/${encodeURIComponent(p.key)}`, title: p.name, path: `/product/${encodeURIComponent(p.key)}`, product: p.key, count: failed(p.rows), bad: true }))
    const fwItems: NavItem[] = model.frameworks.map((f) => ({ key: `/framework/${encodeURIComponent(f.Key)}`, title: frameworkLabel(f), path: `/framework/${encodeURIComponent(f.Key)}`, icon: "framework" as IconName, count: frameworkTally(model, f).Failed, bad: true }))
    if (model.rows.some((t) => t.Mitre.length)) fwItems.push({ key: "§techniques", title: "Techniques", section: true, items: [{ key: "/attack", title: "MITRE ATT&CK", path: "/attack", icon: "attack" }] })
    const rows: NavItem[] = []
    if (productItems.length) {
      const count = products.reduce((n, p) => n + failed(p.rows), 0)
      hubs.push({ key: "products", title: "Products", sub: `${productItems.length} ${productItems.length === 1 ? "product" : "products"} in this run`, icon: "product", path: productItems[0].path!, count, bad: true, items: productItems })
      rows.push({ key: "hub:products", title: "Products", hub: "products", icon: "product", count, bad: true })
    }
    if (fwItems.length) {
      hubs.push({ key: "frameworks", title: "Frameworks", sub: "How this run maps to benchmarks", icon: "framework", path: firstPath(fwItems)!, items: fwItems })
      rows.push({ key: "hub:frameworks", title: "Frameworks", hub: "frameworks", icon: "framework", bad: fwItems.some((f) => f.count) })
    }
    if (rows.length) home.push({ key: "hubs", items: rows })
  }

  const attachments = getReportAttachments(model.result)
  const owned = new Set<string>()
  const packRows: NavItem[] = []
  for (const p of model.packs) {
    const items = packMenu(model, p, extra.plans, attachments)
    for (const a of packAttachments(model, p)) owned.add(a.Id)
    const first = firstPath(items) || `/pack/${encodeURIComponent(packSlug(p))}`
    const key = `pack:${p.Id}`
    const count = failed(p.rows)
    hubs.push({ key, title: p.Name, sub: `${p.BuiltIn ? "Official pack" : "Pack"}${p.Version ? ` · v${p.Version}` : ""}`, code: p.Code, path: first, count, bad: true, items })
    packRows.push({ key: `hub:${key}`, title: p.Name, hub: key, code: p.Code, count, bad: true })
  }
  home.push({ key: "packs", title: "Packs", items: packRows, addPack: true })

  // Reports no pack owns, and the run's details.
  const reports: NavItem[] = attachments.filter((a) => !owned.has(a.Id)).map((a) => ({ key: getAttachmentPath(a), title: a.Name, path: getAttachmentPath(a), icon: "report" }))
  reports.push({ key: "/run", title: "Run details", path: "/run", icon: "duration" })
  home.push({ key: "reports", items: reports })
  return { home, hubs }
}

function firstPath(items: NavItem[]): string | undefined {
  for (const it of items) {
    if (it.path) return it.path
    const p = it.items && firstPath(it.items)
    if (p) return p
  }
}

/** The reports a pack's tests attached. */
function packAttachments(model: Model, p: Pack & { rows: Row[] }): ReportAttachment[] {
  return [...new Map(p.rows.flatMap((t) => getTestAttachments(model.result, { Id: t.Id, ParentId: t.ParentId })).map((a) => [a.Id, a])).values()]
}

/** The menu a pack gets when its manifest declares none. */
function defaultEntries(model: Model, p: Pack & { rows: Row[] }): NavEntry[] {
  const entries: NavEntry[] = [{ Title: "Overview", View: "pack" }]
  const ids = new Set(p.rows.flatMap((t) => [t.Id, t.ParentId]).filter(Boolean))
  const plan = (Array.isArray(model.result?.Attachments) ? model.result.Attachments : []).find((a: ReportAttachment) => a?.Name === WORKSHOP_ATTACHMENT && a.TestId && ids.has(a.TestId))
  if (plan) entries.push({ Section: "Zero Trust plan", Id: "plan", View: "plan", Attachment: WORKSHOP_ATTACHMENT, Expand: ["pillars", "areas", "lanes"] })
  const field = [...new Set(p.rows.flatMap((t) => Object.keys(t.Fields || {})))][0]
  if (field) entries.push({ Section: `By ${field.toLowerCase()}`, Id: slug(field), View: "tests", GroupBy: [field] })
  for (const a of packAttachments(model, p)) entries.push({ Title: a.Name, View: "attachment", Attachment: a.Name })
  if (p.Guide) entries.push({ Section: "Set up", Items: [{ Title: "Get started", Id: "start", View: "guide", Page: "start" }, { Title: "Connect", Id: "connect", View: "guide", Page: "connect" }, { Title: "Run", Id: "run", View: "guide", Page: "run" }] })
  entries.push({ Title: "About this pack", Id: "about", View: "about" })
  return entries
}

function packMenu(model: Model, p: Pack & { rows: Row[] }, plans: Map<string, Plan>, attachments: ReportAttachment[]): NavItem[] {
  const base = `/pack/${encodeURIComponent(packSlug(p))}`
  const entries = p.Navigation || defaultEntries(model, p)
  const used = new Set<string>()
  // Two entries with the same Id get distinct links.
  const idFor = (e: NavEntry) => {
    const root = slug(e.Id || e.Title || e.Section || "page")
    let id = root, n = 2
    while (used.has(id)) id = `${root}-${n++}`
    used.add(id)
    return id
  }

  const build = (e: NavEntry): NavItem[] => {
    const name = (e.Title || e.Section)!
    const id = idFor(e)
    let path: string | undefined
    let page: PackPageDef | undefined
    let icon: IconName | undefined
    let count: number | undefined
    let bad: boolean | undefined
    let expanded: NavItem[] = []
    switch (e.View) {
      case "pack":
        path = base; page = { view: "pack", packId: p.Id, title: p.Name }; icon = "home"
        break
      case "tests": {
        path = `${base}/${id}`
        const filter = Object.fromEntries(Object.entries(e.Filter || {}).map(([k, v]) => [k, Array.isArray(v) ? v : [v]]))
        const rows = p.rows.filter((t) => (!e.Result || t.Result === e.Result) && matches(t, filter))
        page = { view: "tests", packId: p.Id, title: name, result: e.Result, filter, groupBy: e.GroupBy }
        icon = e.Result === "Failed" ? "fix" : "list"
        count = e.Result && e.Result !== "Failed" ? rows.length : failed(rows); bad = !e.Result || e.Result === "Failed"
        expanded = groupRows(rows, e.GroupBy || [], path, page)
        break
      }
      case "plan": {
        const plan = plans.get(e.Attachment!)
        if (!plan && !(Array.isArray(model.result?.Attachments) && model.result.Attachments.some((a: ReportAttachment) => a?.Name === e.Attachment))) return []
        path = `${base}/${id}`; page = { view: "plan", packId: p.Id, title: name, attachment: e.Attachment, planPath: path }; icon = "area"
        if (plan) expanded = planRows(plan, e.Expand || [], path, page)
        break
      }
      case "attachment": {
        const a = attachments.find((x) => x.Name === e.Attachment)
        if (!a) return []
        path = getAttachmentPath(a); icon = "report"
        break
      }
      case "guide":
        if (!p.Guide) return []
        path = `${base}/${id}`; page = { view: "guide", packId: p.Id, title: name, page: e.Page || "start" }; icon = "guide"
        break
      case "about":
        path = `${base}/${id}`; page = { view: "about", packId: p.Id, title: name }; icon = "info"
        break
    }
    const children = [...expanded, ...(e.Items || []).flatMap(build)]
    if (e.Section) {
      // A heading's rows are what its view expands to and its items; a view with nothing to expand is one row.
      const own: NavItem[] = path && !expanded.length ? [{ key: path, title: name, path, page, icon, count, bad }] : []
      const rows = [...own, ...children]
      return rows.length ? [{ key: `${base}§${id}`, title: name, section: true, items: rows }] : []
    }
    if (!path && !children.length) return []
    return [{ key: path || `${base}§${id}`, title: name, path, page, icon, count, bad, items: children.length ? children : undefined }]
  }
  return entries.flatMap(build)
}

const matches = (t: Row, filter: Record<string, string[]>) => Object.entries(filter).every(([k, vs]) => fieldValues(t.Fields || undefined, k).some((v) => vs.includes(v)))

// One row per value of the first field, nesting the next field's values under each.
function groupRows(rows: Row[], fields: string[], path: string, parent: PackPageDef): NavItem[] {
  const [field, ...rest] = fields
  if (!field) return []
  const groups = new Map<string, Row[]>()
  for (const t of rows) for (const v of fieldValues(t.Fields || undefined, field)) { if (!groups.has(v)) groups.set(v, []); groups.get(v)!.push(t) }
  return [...groups.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([v, rs]) => {
    const p = `${path}/${encodeURIComponent(slug(v))}`
    const page: PackPageDef = { ...parent, title: v, filter: { ...(parent.filter || {}), [field]: [v] }, groupBy: rest }
    const items = groupRows(rs, rest, p, page)
    return { key: p, title: v, path: p, page, icon: undefined, count: parent.result && parent.result !== "Failed" ? rs.length : failed(rs), bad: !parent.result || parent.result === "Failed", items: items.length ? items : undefined }
  })
}

// The plan's pillars, their functional areas and swimlanes, as many levels as the entry asks for.
function planRows(plan: Plan, levels: string[], path: string, parent: PackPageDef): NavItem[] {
  if (!levels.includes("pillars")) return []
  const prog = (ts: { st: string }[]): [number, number] => { const ck = ts.filter((t) => t.st !== "manual"); return [ck.filter((t) => t.st === "done").length, ck.length] }
  const open = (ts: { st: string }[]) => ts.filter((t) => t.st === "notdone" || t.st === "partial").length
  return plan.pillars.filter((pl) => pl.tasks.length).map((pl) => {
    const pp = `${path}/${encodeURIComponent(pl.id)}`
    const areas: NavItem[] = levels.includes("areas") ? pl.areas.filter((a) => a.tasks.length).map((a) => {
      const ap = `${pp}/${encodeURIComponent(a.id)}`
      const lanes: NavItem[] = levels.includes("lanes") ? a.lanes.map((l) => {
        const lp = `${ap}/${encodeURIComponent(slug(l.name))}`
        return { key: lp, title: l.name, path: lp, count: open(l.tasks), bad: true, page: { ...parent, title: l.name, pillar: pl.id, area: a.id, lane: slug(l.name) } }
      }) : []
      return { key: ap, title: a.name, path: ap, prog: prog(a.tasks), page: { ...parent, title: a.name, pillar: pl.id, area: a.id }, items: lanes.length ? lanes : undefined }
    }) : []
    return { key: pp, title: pl.name, path: pp, icon: "pillar" as IconName, prog: prog(pl.tasks), page: { ...parent, title: pl.name, pillar: pl.id }, items: areas.length ? areas : undefined }
  })
}

/** Every row with a page, with the rows above it. */
export function* walkItems(items: NavItem[], trail: NavItem[] = []): Generator<{ item: NavItem; trail: NavItem[] }> {
  for (const it of items) {
    if (it.path) yield { item: it, trail }
    if (it.items) yield* walkItems(it.items, it.section ? trail : [...trail, it])
  }
}

/** The row of this path, the hub it is in and the rows above it. An exact match wins; else the deepest row
 * whose path starts the URL (a product's feature, a report). */
export function locate(nav: NavModel, pathname: string): Located {
  let best: Located = { item: null, hub: null, trail: [] }
  let bestLen = -1
  const consider = (item: NavItem, hub: Hub | null, trail: NavItem[]) => {
    const p = item.path!
    if (p === pathname) { if (bestLen < Infinity) { best = { item, hub, trail }; bestLen = Infinity } return }
    if (p !== "/" && pathname.startsWith(p + "/") && p.length > bestLen && bestLen < Infinity) { best = { item, hub, trail }; bestLen = p.length }
  }
  for (const g of nav.home) for (const { item, trail } of walkItems(g.items)) consider(item, null, trail)
  for (const h of nav.hubs) for (const { item, trail } of walkItems(h.items)) consider(item, h, trail)
  return best
}

/** The pack and page a /pack/ path names, or null. An old link with the pack's ID still opens its overview. */
export function packPage(model: Model, nav: NavModel, pathname: string): { pack: (Pack & { rows: Row[] }) | null; page: PackPageDef | null } {
  const [, , key = ""] = pathname.split("/")
  let id = key
  try { id = decodeURIComponent(key) } catch { /* a cut link */ }
  const pack = model.packs.find((p) => packSlug(p) === id || p.Id === id || p.Code.toLowerCase() === id.toLowerCase()) || null
  if (!pack) return { pack: null, page: null }
  const hub = nav.hubs.find((h) => h.key === `pack:${pack.Id}`)
  for (const { item } of hub ? walkItems(hub.items) : []) if (item.path === pathname && item.page) return { pack, page: item.page }
  const rest = pathname.split("/").slice(3)
  if (!rest.length) return { pack, page: { view: "pack", packId: pack.Id, title: pack.Name } }
  // A plan page the menu does not list (its plan is still being read, or the menu stops above it).
  for (const { item } of hub ? walkItems(hub.items) : []) {
    const base = item.page?.view === "plan" ? item.page.planPath : undefined
    if (base && (pathname === base || pathname.startsWith(base + "/"))) {
      const [pillar, area, lane] = pathname.slice(base.length + 1).split("/").map((s) => { try { return decodeURIComponent(s) } catch { return s } })
      return { pack, page: { ...item.page!, title: item.page!.title, pillar: pillar || undefined, area, lane } }
    }
  }
  return { pack, page: null }
}
