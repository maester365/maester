// Every test, with filters for each attribute, a text filter and grouping.

import { useMemo } from "react"
import { RESULT_LABEL, RESULT_ORDER, SEVERITIES, frameworkLabel, frameworkRank, requirementsOf, type Row } from "@/lib/model"
import { useReport } from "@/components/report/ReportContext"
import { Footer, GROUPS, TestTable, sourceLabel } from "@/components/report/lists"
import { Dropdown, FeatureMark, Icon, ProductMark, copyText, type IconName } from "@/components/report/ui"

const GROUP_ICON: Record<string, IconName> = { product: "product", area: "area", feature: "feature", severity: "severity", source: "source", result: "result" }

interface Dimension { key: string; icon: IconName; values: (t: Row) => string[]; label: (v: string) => string; order?: string[]; rank?: (v: string) => number }

export default function TestsPage() {
  const { model, explorer, setExplorer } = useReport()
  const { q, filters, group } = explorer
  const dims: Dimension[] = useMemo(() => ([
    { key: "Result", icon: "result", values: (t) => [t.Result], label: (v) => RESULT_LABEL[v] || v, order: RESULT_ORDER },
    { key: "Severity", icon: "severity", values: (t) => (t.Severity ? [t.Severity] : []), label: (v) => v, order: SEVERITIES },
    { key: "Product", icon: "product", values: (t) => (t.Product ? [t.Product] : []), label: (v) => model.productName(v) },
    { key: "Feature", icon: "feature", values: (t) => (t.Product && t.Feature ? [`${t.Product}/${t.Feature}`] : []), label: (v) => { const t = model.rows.find((r) => `${r.Product}/${r.Feature}` === v); return t ? model.featureName(t) : v } },
    { key: "Area", icon: "area", values: (t) => (t.Area ? [t.Area] : []), label: (v) => model.areaName(v) },
    { key: "Source", icon: "source", values: (t) => [sourceLabel(model, t)].filter(Boolean), label: (v) => v },
    { key: "Framework", icon: "framework", values: (t) => [...new Set(requirementsOf(t).map(([k]) => k))], label: (v) => frameworkLabel({ Key: v, Name: v }), rank: frameworkRank },
  ] as Dimension[]).filter((d) => model.rows.some((t) => d.values(t).length)), [model])

  const query = q.toLowerCase().trim()
  const matches = (t: Row, skip?: string) =>
    dims.every((d) => d.key === skip || !filters[d.key]?.length || d.values(t).some((v) => filters[d.key].includes(v))) &&
    (!query || `${t.Id} ${t.Title} ${t.Mitre.join(" ")} ${t.Control.join(" ")}`.toLowerCase().includes(query))
  const rows = model.rows.filter((t) => matches(t))
  const filtered = Object.values(filters).some((v) => v?.length) || !!query
  const toggle = (key: string, value: string, on: boolean) => {
    const set = new Set(filters[key] || [])
    if (on) set.add(value); else set.delete(value)
    setExplorer({ filters: { ...filters, [key]: [...set] } })
  }
  // Every cell is escaped: an ID can come from a Pester test name, which may hold a pipe or a line break.
  const cell = (v: unknown) => String(v ?? "").replace(/[\\|]/g, "\\$&").replace(/\r?\n/g, " ")
  const copyRows = () => copyText(["| Result | ID | Title | Severity | Product |", "| --- | --- | --- | --- | --- |", ...rows.map((t) => `| ${[t.Result, t.Id, t.Title, t.Severity, model.productName(t.Product)].map(cell).join(" | ")} |`)].join("\n"), `Copied ${rows.length} rows`)
  const groups = Object.keys(GROUPS).filter((g) => g !== "feature" || model.hasAttributes)

  return (
    <div className="mt-wrap wide">
      <div className="mt-headrow">
        <div className="mt-head"><div className="mt-eyebrow">All tests</div><h1 className="mt-h1">{rows.length === model.rows.length ? `${rows.length} tests` : `${rows.length} of ${model.rows.length} tests`}</h1></div>
        <button type="button" className="mt-btn" onClick={copyRows}>Copy as Markdown</button>
      </div>
      <div className="mt-explorer">
        <aside className="mt-facets" aria-label="Filters">
          {dims.map((d) => {
            const counts = new Map<string, number>()
            for (const t of model.rows) if (matches(t, d.key)) for (const v of d.values(t)) counts.set(v, (counts.get(v) || 0) + 1)
            const values = [...counts.keys()].sort((a, b) => (d.order ? d.order.indexOf(a) - d.order.indexOf(b) : d.rank ? d.rank(a) - d.rank(b) : counts.get(b)! - counts.get(a)!))
            return (
              <div key={d.key} className="mt-facet">
                <h5><Icon name={d.icon} />{d.key}</h5>
                {values.slice(0, 12).map((v) => (
                  <label key={v}>
                    <input type="checkbox" checked={(filters[d.key] || []).includes(v)} onChange={(e) => toggle(d.key, v, (e.target as HTMLInputElement).checked)} />
                    {d.key === "Product" && <ProductMark product={v} size="sm" />}{d.key === "Feature" && <FeatureMark product={v.split("/")[0]} feature={v.split("/")[1]} />}<span>{d.label(v)}</span><span className="c">{counts.get(v)}</span>
                  </label>
                ))}
              </div>
            )
          })}
        </aside>
        <div className="mt-sec">
          <div className="mt-toolbar">
            <input className="mt-input" type="search" placeholder="Filter by ID, title, ATT&CK technique or control" value={q} aria-label="Filter tests" onInput={(e) => setExplorer({ q: (e.target as HTMLInputElement).value })} />
            <Dropdown label="Group by" value={group} onChange={(g) => setExplorer({ group: g })}
              options={groups.map((g) => ({ value: g, label: GROUPS[g], icon: GROUP_ICON[g] ? <Icon name={GROUP_ICON[g]} /> : undefined }))} />
            {filtered && <button type="button" className="mt-btn" onClick={() => setExplorer({ q: "", filters: {} })}>Clear filters</button>}
          </div>
          <TestTable rows={rows} group={group} />
        </div>
      </div>
      <Footer />
    </div>
  )
}
