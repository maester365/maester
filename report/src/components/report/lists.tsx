// Lists of tests: the table every view uses, with optional grouping, and the ranked "fix these first" list.

import { useEffect, useRef, useState, type ReactNode } from "react"
import { RESULT_LABEL, RESULT_ORDER, SEVERITIES, isQuickWin, maesterVersion, sortTests, tally, type Model, type Row } from "@/lib/model"
import { reportHeading } from "@/lib/runSubject"
import { useReport } from "./ReportContext"
import { FeatureMark, Icon, Pill, ProductMark, Sev } from "./ui"

export const GROUPS: Record<string, string> = { none: "No grouping", product: "Product", area: "Area", feature: "Feature", severity: "Severity", source: "Source", result: "Result" }

export function sourceLabel(model: Model, t: Row) {
  const pack = model.packOf(t)
  return pack ? pack.Name : t.Suite || t.Source || ""
}

const rank = (order: string[], value: string) => { const i = order.indexOf(value); return i === -1 ? order.length : i }
const text = (a: string, b: string) => a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" })
const LEVELS = ["Low", "Medium", "High"]

interface Column {
  key: string
  label: string
  /** Always shown: the result and the test. */
  fixed?: boolean
  /** Shown until the reader picks other columns. */
  standard?: boolean
  /** Hidden on narrow screens. */
  wide?: boolean
  /** The text a column sorts by; empty when the test has none. */
  value: (model: Model, t: Row) => string
  compare?: (a: string, b: string) => number
  cell: (model: Model, t: Row) => ReactNode
}

const plain = (v: string | null | undefined) => (v ? <span className="mt-ell" title={v}>{v}</span> : <span className="mt-muted">—</span>)
const codes = (list: string[]) => list.length ? <span className="mt-mono mt-codes" title={list.join(", ")}>{list.slice(0, 2).join(", ")}{list.length > 2 && <span className="mt-muted"> +{list.length - 2}</span>}</span> : <span className="mt-muted">—</span>

// The columns a test list can show and sort by. Ascending is the order a reader looks for first: failures first,
// the most severe first, the least effort first, A to Z. A second click on a column reverses it, a third goes back
// to the usual order.
export const COLUMNS: Column[] = [
  { key: "result", label: "Result", fixed: true, value: (_, t) => t.Result, compare: (a, b) => rank(RESULT_ORDER, a) - rank(RESULT_ORDER, b), cell: (_, t) => <Pill result={t.Result} /> },
  { key: "id", label: "Test", fixed: true, value: (_, t) => t.Id, compare: (a, b) => a.localeCompare(b, undefined, { numeric: true }),
    cell: (_, t) => <div style={{ display: "flex", flexDirection: "column", gap: 2 }}><span>{t.Title}</span><span className="mt-mono mt-muted" style={{ fontSize: 11.5 }}>{t.Id}</span></div> },
  { key: "product", label: "Product", standard: true, wide: true, value: (m, t) => (t.Product ? m.productName(t.Product) : ""),
    cell: (m, t) => <span style={{ display: "inline-flex", gap: 7, alignItems: "center", whiteSpace: "nowrap" }}><ProductMark product={t.Product} size="sm" />{m.productName(t.Product)}</span> },
  { key: "feature", label: "Feature", wide: true, value: (m, t) => (t.Feature ? m.featureName(t) : ""),
    cell: (m, t) => (t.Feature ? <span style={{ display: "inline-flex", gap: 7, alignItems: "center", whiteSpace: "nowrap" }}><FeatureMark product={t.Product} feature={t.Feature} />{m.featureName(t)}</span> : plain(null)) },
  { key: "area", label: "Area", wide: true, value: (m, t) => (t.Area ? m.areaName(t.Area) : ""), cell: (m, t) => plain(t.Area ? m.areaName(t.Area) : null) },
  { key: "severity", label: "Severity", standard: true, value: (_, t) => (SEVERITIES.includes(t.Severity) ? t.Severity : ""), compare: (a, b) => rank(SEVERITIES, a) - rank(SEVERITIES, b), cell: (_, t) => <Sev severity={t.Severity} /> },
  { key: "impact", label: "User impact", wide: true, value: (_, t) => t.UserImpact || "", compare: (a, b) => rank(LEVELS, a) - rank(LEVELS, b), cell: (_, t) => plain(t.UserImpact) },
  { key: "effort", label: "Effort", wide: true, value: (_, t) => t.ImplementationCost || "", compare: (a, b) => rank(LEVELS, a) - rank(LEVELS, b), cell: (_, t) => plain(t.ImplementationCost) },
  { key: "resource", label: "Resource", wide: true, value: (_, t) => t.ResourceType || "", cell: (_, t) => plain(t.ResourceType) },
  { key: "mitre", label: "ATT&CK", wide: true, value: (_, t) => t.Mitre.join(", "), cell: (_, t) => codes(t.Mitre) },
  { key: "control", label: "Controls", wide: true, value: (_, t) => t.Control.join(", "), cell: (_, t) => codes(t.Control) },
  { key: "source", label: "Source", standard: true, wide: true, value: (m, t) => sourceLabel(m, t), cell: (m, t) => <span className="mt-ell mt-muted" title={sourceLabel(m, t)}>{sourceLabel(m, t)}</span> },
  { key: "duration", label: "Duration", wide: true, value: (_, t) => t.Duration || "", cell: (_, t) => <span className="mt-mono mt-muted">{t.Duration || "—"}</span> },
]

export const STANDARD_COLUMNS = COLUMNS.filter((c) => c.standard).map((c) => c.key)

/** The rows in the order of a sort ("severity", "-id"), or the usual order when there is none. Rows without a value
 * (no severity, no product) stay last either way; ties keep the usual order. */
export function sortRows(model: Model, rows: Row[], sort: string) {
  const usual = sortTests(rows)
  const column = COLUMNS.find((c) => c.key === sort.replace(/^-/, ""))
  if (!column) return usual
  const compare = column.compare ?? text
  const dir = sort.startsWith("-") ? -1 : 1
  return usual.sort((a, b) => {
    const x = column.value(model, a), y = column.value(model, b)
    return !x || !y ? Number(!x) - Number(!y) : dir * compare(x, y)
  })
}

/** The optional columns a report can show (those some test has a value for) and the columns a list shows. */
export function visibleColumns(model: Model, chosen: string[]) {
  const available = COLUMNS.filter((c) => !c.fixed && (c.standard || model.rows.some((t) => c.value(model, t))))
  const shown = COLUMNS.filter((c) => c.fixed || (chosen.includes(c.key) && available.includes(c)))
  return { available, shown }
}

/** The sort, or none when its column is not shown. */
export const shownSort = (shown: Column[], sort: string) => (shown.some((c) => c.key === sort.replace(/^-/, "")) ? sort : "")

/** The rows of a list in the order it shows them: sorted, then gathered into groups when it is grouped. */
export function groupRows(model: Model, rows: Row[], group: string, sort: string) {
  const sorted = sortRows(model, rows, sort)
  let groups: [string, Row[]][] = []
  if (group !== "none") {
    const byKey = new Map<string, Row[]>()
    for (const t of sorted) { const k = groupKey(model, group, t); if (!byKey.has(k)) byKey.set(k, []); byKey.get(k)!.push(t) }
    // Sorted by the column the list is grouped by, the groups follow the sort (the rows are already in its order,
    // tests without a value last); otherwise the groups with the most failures come first. A pack's own field can
    // share a column's name (id) without being that column, so only Maester's groupings count.
    groups = group in GROUPS && sort.replace(/^-/, "") === group ? [...byKey.entries()] : [...byKey.entries()].sort((a, b) => tally(b[1]).Failed - tally(a[1]).Failed)
  }
  return { sorted, groups, ordered: group === "none" ? sorted : groups.flatMap(([, list]) => list) }
}

/** The button that picks the columns a test list shows, for every list in the report. */
function ColumnPicker({ chosen, onChange, available }: { chosen: string[]; onChange: (keys: string[] | ((current: string[]) => string[])) => void; available: Column[] }) {
  const [open, setOpen] = useState(false)
  const [at, setAt] = useState({ top: 0, right: 0 })
  const root = useRef<HTMLDivElement>(null)
  // The list is placed against the window: the table's scrolling box would clip it.
  const place = () => {
    const r = root.current?.getBoundingClientRect()
    if (r) setAt({ top: r.bottom + 6, right: Math.max(8, window.innerWidth - r.right) })
  }
  useEffect(() => {
    if (!open) return
    const close = () => { setOpen(false) }
    window.addEventListener("scroll", close, true)
    window.addEventListener("resize", close)
    const away = (e: MouseEvent) => { if (!root.current?.contains(e.target as Node)) setOpen(false) }
    const esc = (e: KeyboardEvent) => { if (e.key === "Escape") { e.stopPropagation(); setOpen(false); root.current?.querySelector("button")?.focus() } }
    document.addEventListener("mousedown", away)
    document.addEventListener("keydown", esc, true)
    return () => { document.removeEventListener("mousedown", away); document.removeEventListener("keydown", esc, true); window.removeEventListener("scroll", close, true); window.removeEventListener("resize", close) }
  }, [open])
  const showColumn = (key: string, on: boolean) => { onChange((current) => COLUMNS.filter((c) => !c.fixed && (c.key === key ? on : current.includes(c.key))).map((c) => c.key)) }
  return (
    <div className="mt-cols" ref={root}>
      <button type="button" className="mt-cols-btn" aria-haspopup="true" aria-expanded={open} onClick={() => { place(); setOpen((o) => !o) }} title="Choose columns" aria-label="Choose columns">
        <Icon name="columns" />
      </button>
      {open && (
        <div className="mt-cols-list" role="group" aria-label="Columns" style={{ top: at.top, right: at.right }}>
          <div className="mt-cols-h">Columns</div>
          {available.map((c) => (
            <label key={c.key}>
              <input type="checkbox" checked={chosen.includes(c.key)} onChange={(e) => { showColumn(c.key, e.currentTarget.checked) }} />{c.label}
            </label>
          ))}
          <button type="button" className="mt-cols-reset" onClick={() => { onChange(STANDARD_COLUMNS) }}>Reset to default</button>
        </div>
      )}
    </div>
  )
}

const nextSort = (sort: string, key: string) => (sort === key ? `-${key}` : sort === `-${key}` ? "" : key)

function groupKey(model: Model, group: string, t: Row): string {
  switch (group) {
    case "product": return model.productName(t.Product)
    case "area": return model.areaName(t.Area) || "Other"
    case "feature": return model.featureName(t) || "Other"
    case "severity": return t.Severity || "Not set"
    case "source": return sourceLabel(model, t) || "Other"
    case "result": return RESULT_LABEL[t.Result] || t.Result
    default: {
      // A pack field, such as Pillar.
      const value = t.Fields?.[group]
      return (Array.isArray(value) ? value[0] : value) || "Other"
    }
  }
}

export function TestTable({ rows, group = "none", empty = "No tests match these filters.", sort: sortProp, onSort }: { rows: Row[]; group?: string; empty?: string; sort?: string; onSort?: (sort: string) => void }) {
  const { model, openTest, columns: chosen, setColumns } = useReport()
  // Columns no test in the report has a value for are left out of the table and the picker.
  const { available, shown } = visibleColumns(model, chosen)
  // A list keeps its own sort unless the page holds it (the All tests page keeps it with its filters).
  const [ownSort, setOwnSort] = useState("")
  const sort = sortProp ?? ownSort
  const setSort = onSort ?? setOwnSort
  // A sort by a column the reader has hidden is ignored: the order would have no header to show it or undo it.
  const { sorted, groups, ordered } = groupRows(model, rows, group, shownSort(shown, sort))
  const order = ordered.map((t) => t.Id)
  const open = (id: string) => openTest(id, order)
  const row = (t: Row) => (
    <tr key={t.Id} className="click" tabIndex={0} onClick={() => open(t.Id)} onKeyDown={(e) => { if (e.key === "Enter") open(t.Id) }}>
      {shown.map((c) => <td key={c.key} className={c.key === "id" ? "ttl" : c.wide ? "mt-hide-sm" : undefined}>{c.cell(model, t)}</td>)}
      <td className="mt-cols-cell" />
    </tr>
  )
  let body
  if (group === "none") body = sorted.map(row)
  else {
    body = groups.flatMap(([k, list]) => {
      const c = tally(list)
      return [<tr key={`g-${k}`} className="grp"><td colSpan={shown.length + 1}>{group === "feature" && <FeatureMark product={list[0].Product} feature={list[0].Feature} />}{group === "product" && <ProductMark product={list[0].Product} size="sm" />}{k} <span>· {c.Failed} failed of {c.total}</span></td></tr>, ...list.map(row)]
    })
  }
  return (
    <div className="mt-tablewrap">
      <table className="mt-table mt-tests">
        <thead><tr>{shown.map((c) => {
          const dir = sort === c.key ? "ascending" : sort === `-${c.key}` ? "descending" : undefined
          return (
            <th key={c.key} className={c.wide ? "mt-hide-sm" : undefined} aria-sort={dir}>
              <button type="button" className="mt-sort" onClick={() => { setSort(nextSort(sort, c.key)) }} title={c.key === "id" ? "Sort by test ID" : `Sort by ${c.label.toLowerCase()}`}>
                {c.label}<span className="mt-sort-i" aria-hidden="true">{dir === "ascending" ? "▲" : dir === "descending" ? "▼" : "↕"}</span>
              </button>
            </th>
          )
        })}<th className="mt-cols-th"><ColumnPicker chosen={chosen} onChange={setColumns} available={available} /></th></tr></thead>
        <tbody>{rows.length ? body : <tr><td colSpan={shown.length + 1} className="mt-empty">{empty}</td></tr>}</tbody>
      </table>
    </div>
  )
}

export function FixList({ rows, limit }: { rows: Row[]; limit: number }) {
  const { model, openTest } = useReport()
  return (
    <div className="mt-card mt-fix">
      {rows.slice(0, limit).map((t, i) => (
        <button key={t.Id} type="button" className="mt-fixrow" onClick={() => openTest(t.Id, rows.slice(0, limit).map((r) => r.Id))}>
          <span className="rank">{String(i + 1).padStart(2, "0")}</span>
          <span>
            <div className="t">{t.Title}</div>
            <div className="m">
              <ProductMark product={t.Product} size="sm" /><span>{model.productName(t.Product)}</span><span>·</span><span className="mt-mono">{t.Id}</span>
              {model.changes.newlyFailing.includes(t) && <span className="mt-badge bad">New since last run</span>}
            </div>
          </span>
          <span className="why">
            <Sev severity={t.Severity} />
            {isQuickWin(t) ? <span className="mt-badge good">Quick win</span> : <>
              {t.ImplementationCost && <span className="mt-badge">Effort {t.ImplementationCost}</span>}
              {t.UserImpact && <span className="mt-badge">User impact {t.UserImpact}</span>}
            </>}
          </span>
        </button>
      ))}
    </div>
  )
}

export function Footer() {
  const { model, models, multi } = useReport()
  return (
    <div className="mt-foot">
      <span>Generated by Maester {maesterVersion(model.result)} · <a className="mt-link" href="https://maester.dev" target="_blank" rel="noopener noreferrer">maester.dev</a> · Run it on a schedule with <a className="mt-link" href="https://maester.cloud/?ref=report" target="_blank" rel="noopener noreferrer">maester.cloud</a></span>
      <span>This report holds configuration data from {multi ? `${models.length} tenants` : reportHeading(model).holds}. Share it only with people who may see it.</span>
    </div>
  )
}
