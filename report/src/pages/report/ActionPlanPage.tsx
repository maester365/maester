// Every failure, ranked, with the effort and user-impact grid: start where fixes are cheap and users won't notice.

import { useState } from "react"
import { Link } from "@/lib/router"
import { SEVERITIES, priority, severityWeight } from "@/lib/model"
import { useReport } from "@/components/report/ReportContext"
import { FixList, Footer } from "@/components/report/lists"
import { ProductMark } from "@/components/report/ui"

const LEVELS = ["Low", "Medium", "High"]
const SEVERITY_COLOUR: Record<string, string> = { Critical: "var(--mt-fail)", High: "var(--mt-high)", Medium: "var(--mt-warn)", Low: "var(--mt-skip)", Info: "var(--mt-info)" }

export default function ActionPlanPage() {
  const { model, explore } = useReport()
  const [cell, setCell] = useState<[string, string] | null>(null)
  const failing = model.failing
  const inCell = (impact: string, effort: string) => failing.filter((t) => (t.UserImpact || "Medium") === impact && (t.ImplementationCost || "Medium") === effort)
  const list = cell ? inCell(cell[0], cell[1]).sort((a, b) => priority(b) - priority(a)) : model.ranked
  const byProduct = model.products.map((p) => ({ p, rows: p.rows.filter((t) => t.Result === "Failed") })).filter((x) => x.rows.length).sort((a, b) => b.rows.length - a.rows.length)
  const hasLevels = failing.some((t) => t.UserImpact || t.ImplementationCost)

  return (
    <div className="mt-wrap">
      <div className="mt-head">
        <div className="mt-eyebrow">Action plan</div>
        <h1 className="mt-h1">{failing.length} failures, ranked by what to fix first</h1>
        <p className="mt-lead">Each test says how much its fix disrupts users and how much work it is. Start in the green corner: fixes that are cheap and that users won't notice.</p>
      </div>
      <div className="mt-grid mt-g2" style={{ alignItems: "start" }}>
        {hasLevels && (
          <div className="mt-card mt-pad mt-sec">
            <h2 className="mt-h2">Effort and user impact</h2>
            <div className="mt-matrix">
              <span />
              {LEVELS.map((l) => <span key={l} className="ax">Effort {l}</span>)}
              {LEVELS.flatMap((impact) => [
                <span key={`a${impact}`} className="ax">User impact {impact}</span>,
                ...LEVELS.map((effort) => {
                  const rows = inCell(impact, effort)
                  const on = !!cell && cell[0] === impact && cell[1] === effort
                  return (
                    <button key={impact + effort} type="button" className={`mt-cell${impact === "Low" && effort === "Low" ? " best" : ""}`} aria-pressed={on} onClick={() => setCell(on ? null : [impact, effort])}>
                      <b className="mt-num">{rows.length}</b><span>{rows.filter((t) => severityWeight(t.Severity) >= 3).length} high severity</span>
                    </button>
                  )
                }),
              ])}
            </div>
            <p className="mt-note">{cell ? <>Showing user impact {cell[0]}, effort {cell[1]}. <button type="button" className="mt-link" style={{ border: 0, background: "none", padding: 0 }} onClick={() => setCell(null)}>Show all</button></> : "Choose a cell to list its tests."}</p>
          </div>
        )}
        {byProduct.length > 0 && (
          <div className="mt-card mt-pad mt-sec">
            <h2 className="mt-h2">Where the work is</h2>
            {byProduct.map(({ p, rows }) => (
              <Link key={p.key} to={`/product/${encodeURIComponent(p.key)}`} style={{ display: "grid", gridTemplateColumns: "22px minmax(0,1fr) 1.2fr 34px", gap: 10, alignItems: "center", fontSize: 13 }}>
                <ProductMark product={p.key} /><span>{p.name}</span>
                <span className="mt-bar thin">{SEVERITIES.map((s) => { const n = rows.filter((t) => t.Severity === s).length; return n ? <i key={s} style={{ width: `${(n / rows.length) * 100}%`, background: SEVERITY_COLOUR[s] }} /> : null })}</span>
                <b className="mt-num" style={{ textAlign: "right" }}>{rows.length}</b>
              </Link>
            ))}
            <div className="mt-legend">{["High", "Medium", "Low"].map((s) => <span key={s}><i style={{ background: SEVERITY_COLOUR[s] }} />{s}</span>)}</div>
          </div>
        )}
      </div>
      <FixList rows={list} limit={50} />
      {list.length > 50 && <p className="mt-note">{list.length - 50} more in <a href="#/tests" className="mt-link" onClick={(e) => { e.preventDefault(); explore({ filters: { Result: ["Failed"] } }) }}>the test list</a>.</p>}
      <Footer />
    </div>
  )
}
