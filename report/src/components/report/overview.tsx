// The overview's summary pieces: headline cards, the pass-rate trend, the compliance posture grid, the attacker
// outcomes as tabs, and the objects the run checked.

import { useState, type KeyboardEvent } from "react"
import { Link, useNavigate } from "@/lib/router"
import { OUTCOMES, REASONS, frameworkLabel, isQuickWin, tally, type Row } from "@/lib/model"
import { objectsChecked, postureGrid, runHistory, type RunPoint } from "@/lib/insights"
import { ICON_BASE } from "@/lib/featureIcons"
import { band } from "@/lib/tenants"
import { useReport } from "./ReportContext"
import { FixList } from "./lists"
import { Bar, Icon, ProductMark, formatDate, plural, type IconName } from "./ui"

const SEVERITY_DOT: Record<string, string> = { Critical: "var(--mt-fail)", High: "var(--mt-high)", Medium: "var(--mt-warn)", Low: "var(--mt-skip)" }

function Delta({ now, before }: { now: number | null; before: number | null | undefined }) {
  if (now === null || before === null || before === undefined) return null
  const d = now - before
  if (d === 0) return <span className="mt-dl flat" title="Same as the previous run">→ 0</span>
  return <span className={`mt-dl ${d > 0 ? "good" : "bad"}`} title={`${d > 0 ? "Up" : "Down"} ${Math.abs(d)} points since the previous run`}>{d > 0 ? "↗" : "↘"} {Math.abs(d)}</span>
}

interface Chip { label: string; n: number | string; colour?: string; onClick?: () => void; to?: string }

function Kpi({ icon, label, value, note, noteTone, chips, onClick }: { icon: IconName; label: string; value: number | string; note?: string; noteTone?: "up" | "down"; chips: Chip[]; onClick?: () => void }) {
  // The card's own action is a button laid under its content, so the chips stay buttons and links of their own
  // rather than controls nested inside a button.
  return (
    <div className={`mt-card mt-kpi${onClick ? " click" : ""}`}>
      {onClick && <button type="button" className="mt-kpi-hit" onClick={onClick} aria-label={`${label}: ${value}. Show these tests`} />}
      <span className="k"><Icon name={icon} />{label}</span>
      <span className="v"><b className="mt-num">{value}</b>{note && <small className={noteTone === "up" ? "mt-up" : noteTone === "down" ? "mt-down" : "mt-muted"}>{note}</small>}</span>
      {chips.length > 0 && (
        <span className="chips">
          {chips.map((c) => {
            const body = <>{c.colour && <i style={{ background: c.colour }} />}{c.label} <b className="mt-num">{c.n}</b></>
            if (c.to) return <Link key={c.label} to={c.to} className="mt-kchip" onClick={(e) => e.stopPropagation()}>{body}</Link>
            if (c.onClick) return <button key={c.label} type="button" className="mt-kchip" onClick={(e) => { e.stopPropagation(); c.onClick!() }}>{body}</button>
            return <span key={c.label} className="mt-kchip">{body}</span>
          })}
        </span>
      )}
    </div>
  )
}

/** Headline cards, each opening the tests behind its number. */
export function Kpis() {
  const { model, explore } = useReport()
  const navigate = useNavigate()
  const failing = model.failing
  const severe = failing.filter((t) => t.Severity === "Critical" || t.Severity === "High")
  const quick = failing.filter(isQuickWin)
  const notRun = model.rows.filter((t) => t.Result === "Skipped" || t.Result === "NotRun" || t.Result === "Error")
  const reasons = new Map<string, number>()
  for (const t of notRun) { const code = t.ReasonCode || (t.Result === "Error" ? "TestError" : "NotApplicable"); reasons.set(code, (reasons.get(code) || 0) + 1) }
  const grid = postureGrid(model)
  // A framework none of whose requirements has a result has no rate, and is left out of the average.
  const rated = grid.filter((g) => g.now.rate !== null && g.now.rate !== undefined)
  const newly = model.changes.newlyFailing.length
  const failedFilter = { Result: ["Failed"] }
  return (
    <div className="mt-kpis">
      <Kpi icon="finding" label="Failed" value={failing.length} note={model.previous ? `+${newly} new` : undefined} noteTone={newly ? "up" : undefined} onClick={() => explore({ filters: failedFilter })}
        chips={["Critical", "High", "Medium", "Low"].map((s) => ({ label: s, n: failing.filter((t) => t.Severity === s).length, colour: SEVERITY_DOT[s], onClick: () => explore({ filters: { Result: ["Failed"], Severity: [s] } }) })).filter((c) => c.n)} />
      <Kpi icon="severity" label="Critical and high" value={severe.length} note={model.previous ? `${model.changes.newlyFailing.filter((t) => severe.includes(t)).length} new` : undefined} onClick={() => explore({ filters: { Result: ["Failed"], Severity: ["Critical", "High"] } })}
        chips={[{ label: "Quick to fix", n: severe.filter(isQuickWin).length }, { label: "With ATT&CK", n: severe.filter((t) => t.Mitre.length).length }]} />
      <Kpi icon="effort" label="Quick wins" value={quick.length} note="low effort, low impact" onClick={quick.length ? () => navigate("/plan") : undefined}
        chips={[{ label: "Fixed since last run", n: model.changes.fixed.length }]} />
      <Kpi icon="service" label="Did not run" value={notRun.length} onClick={() => explore({ filters: { Result: [...new Set(notRun.map((t) => t.Result))] } })}
        chips={[...reasons.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3).map(([code, n]) => ({ label: (REASONS[code] || [code])[0].replace(/\.$/, ""), n }))} />
      {grid.length > 0 && (
        <Kpi icon="framework" label="Frameworks" value={rated.length ? `${Math.round(rated.reduce((s, g) => s + (g.now.rate as number), 0) / rated.length)}%` : "–"} note="requirements met, on average"
          chips={grid.map((g) => ({ label: frameworkLabel(g.framework).replace(/ Microsoft 365$/, ""), n: `${g.now.rate ?? "–"}%`, to: `/framework/${encodeURIComponent(g.framework.Key)}` }))} />
      )}
    </div>
  )
}

/** The pass rate of this run and the earlier ones the output folder holds, as a line. */
export function Trend({ points, compact }: { points?: RunPoint[]; compact?: boolean }) {
  const { model } = useReport()
  const data = (points || runHistory(model)).filter((p) => p.rate !== null)
  if (data.length < 2) return null
  const w = compact ? 120 : 320
  const h = compact ? 28 : 64
  const pad = compact ? 3 : 6
  const rates = data.map((p) => p.rate as number)
  const lo = Math.max(0, Math.min(...rates) - 5)
  const hi = Math.min(100, Math.max(...rates) + 5)
  const x = (i: number) => pad + (i / (data.length - 1)) * (w - pad * 2)
  const y = (r: number) => h - pad - ((r - lo) / Math.max(1, hi - lo)) * (h - pad * 2)
  const line = data.map((p, i) => `${i ? "L" : "M"}${x(i).toFixed(1)} ${y(p.rate as number).toFixed(1)}`).join(" ")
  const first = data[0]
  const last = data[data.length - 1]
  const label = `Pass rate over ${data.length} runs, from ${first.rate}% on ${formatDate(first.at)} to ${last.rate}% now`
  const svg = (
    <svg className="mt-trend" viewBox={`0 0 ${w} ${h}`} width={w} height={h} role="img" aria-label={label} preserveAspectRatio="none">
      <path d={`${line} L${x(data.length - 1)} ${h} L${x(0)} ${h} Z`} fill="var(--mt-pass)" opacity=".1" />
      <path d={line} fill="none" stroke="var(--mt-pass)" strokeWidth={compact ? 1.5 : 2} strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" />
      {!compact && data.map((p, i) => <circle key={p.at} cx={x(i)} cy={y(p.rate as number)} r={p.current ? 3.5 : 2.2} fill={p.current ? "var(--mt-pass)" : "var(--mt-paper)"} stroke="var(--mt-pass)" strokeWidth="1.5" vectorEffect="non-scaling-stroke"><title>{`${formatDate(p.at)}: ${p.rate}% passed, ${p.failed} failed`}</title></circle>)}
    </svg>
  )
  if (compact) return svg
  const change = (last.rate as number) - (first.rate as number)
  return (
    <div className="mt-trendbox">
      <div className="mt-sechead"><span className="mt-note" style={{ margin: 0 }}>Pass rate, last {data.length} runs</span><span className={`mt-dl ${change > 0 ? "good" : change < 0 ? "bad" : "flat"}`} style={{ fontSize: 12 }}>{change > 0 ? "↗" : change < 0 ? "↘" : "→"} {Math.abs(change)} points since {formatDate(first.at)}</span></div>
      {svg}
    </div>
  )
}

/** Frameworks by attacker outcome, as a compliance posture grid: failed tests in each cell, coloured by pass rate. */
export function Posture() {
  const { model, explore } = useReport()
  const grid = postureGrid(model)
  if (!grid.length) return null
  const cols = OUTCOMES.map((o, i) => ({ o, i })).filter(({ i }) => grid.some((g) => g.cells[i].total))
  return (
    <section className="mt-sec">
      <div className="mt-sechead"><h2 className="mt-h2">Compliance posture</h2><span className="mt-note">Failed tests by framework and by what an attacker could do. Colour shows the pass rate.</span></div>
      <div className="mt-tablewrap">
        <table className="mt-table mt-heatgrid mt-posture">
          <thead><tr><th>Framework</th>{cols.map(({ o }) => <th key={o.short} title={o.title}>{o.short}</th>)}</tr></thead>
          <tbody>
            {grid.map((g) => (
              <tr key={g.framework.Key}>
                <th scope="row">
                  <Link to={`/framework/${encodeURIComponent(g.framework.Key)}`} className="mt-pfw">
                    <b>{frameworkLabel(g.framework)}</b>
                    <span><span className="mt-num">{g.now.rate ?? "–"}% met</span><Delta now={g.now.rate} before={g.before?.rate} /></span>
                  </Link>
                </th>
                {cols.map(({ o, i }) => {
                  const c = g.cells[i]
                  if (!c.total) return <td key={o.short}><span className="mt-heat" data-band="none">–</span></td>
                  return (
                    <td key={o.short}>
                      <button type="button" className="mt-heat" data-band={band(c.rate)} onClick={() => explore({ filters: { Framework: [g.framework.Key], Area: o.areas } })} aria-label={`${frameworkLabel(g.framework)}, ${o.title}: ${c.failed} failed of ${c.total}`}>
                        {c.failed}<small>of {c.total}</small>
                      </button>
                    </td>
                  )
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-note" style={{ margin: 0 }}>The arrow compares the share of requirements met with the previous run. Select a cell to see its tests.</p>
    </section>
  )
}

/** What an attacker could do, one tab per outcome: what is open, what was fixed, which products, what to fix first. */
export function AttackAreas() {
  const { model, explore } = useReport()
  const areas = OUTCOMES.map((o) => ({ o, rows: model.rows.filter((t) => t.Area && o.areas.includes(t.Area)) })).filter((a) => a.rows.length)
  const worst = areas.reduce((best, a, i) => (tally(a.rows).Failed > tally(areas[best]?.rows || []).Failed ? i : best), 0)
  const [sel, setSel] = useState(worst)
  if (!areas.length) return null
  const current = areas[Math.min(sel, areas.length - 1)]
  const c = tally(current.rows)
  const failing = current.rows.filter((t) => t.Result === "Failed")
  const ranked = model.ranked.filter((t) => current.rows.includes(t))
  const newly = model.changes.newlyFailing.filter((t) => current.rows.includes(t))
  const fixed = model.changes.fixed.filter((t) => current.rows.includes(t))
  const byProduct = new Map<string | null, Row[]>()
  for (const t of current.rows) { if (!byProduct.has(t.Product)) byProduct.set(t.Product, []); byProduct.get(t.Product)!.push(t) }
  const products = [...byProduct.entries()].map(([k, rows]) => ({ k, c: tally(rows) })).sort((a, b) => b.c.Failed - a.c.Failed).slice(0, 5)
  const maxFailed = Math.max(1, ...products.map((p) => p.c.Failed))
  const onKey = (e: KeyboardEvent<HTMLButtonElement>) => {
    if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return
    const next = (sel + (e.key === "ArrowRight" ? 1 : -1) + areas.length) % areas.length
    setSel(next)
    window.setTimeout(() => (e.currentTarget.parentElement?.querySelector(`[data-i="${next}"]`) as HTMLElement | null)?.focus(), 0)
  }
  return (
    <section className="mt-sec">
      <div className="mt-sechead"><h2 className="mt-h2">What an attacker could do</h2><a href="#/tests" onClick={(e) => { e.preventDefault(); explore({ group: "area" }) }}>Group the test list by area →</a></div>
      <div className="mt-card mt-areas">
        <div className="mt-tabs" role="tablist" aria-label="Attacker outcomes">
          {areas.map((a, i) => {
            const n = tally(a.rows).Failed
            return <button key={a.o.title} type="button" role="tab" data-i={i} aria-selected={i === sel} tabIndex={i === sel ? 0 : -1} onClick={() => setSel(i)} onKeyDown={onKey}>{a.o.short}{n ? <span className="n bad">{n}</span> : null}</button>
          })}
        </div>
        <div className="mt-areabody" role="tabpanel">
          <div><h3 className="mt-h2" style={{ fontSize: 16 }}>{current.o.title}</h3><p className="mt-note" style={{ margin: "4px 0 0" }}>{current.o.text}</p></div>
          <div className="mt-grid mt-g3">
            <div className="mt-areacard is-open">
              <span className="k">Open</span>
              <b className="mt-num">{c.Failed}</b>
              {model.previous ? <span className={newly.length ? "mt-up" : "mt-muted"}>{newly.length ? `+${newly.length} new since ${formatDate(model.previous.ExecutedAt)}` : `None new since ${formatDate(model.previous.ExecutedAt)}`}</span> : <span className="mt-muted">of {plural(c.total, "test")}</span>}
              <span className="chips">{["Critical", "High", "Medium", "Low"].map((s) => [s, failing.filter((t) => t.Severity === s).length] as [string, number]).filter(([, n]) => n).map(([s, n]) => <span key={s} className="mt-kchip"><i style={{ background: SEVERITY_DOT[s] }} />{s} <b className="mt-num">{n}</b></span>)}</span>
            </div>
            <div className="mt-areacard is-fixed">
              <span className="k">{model.previous ? "Fixed since last run" : "Passed"}</span>
              <b className="mt-num">{model.previous ? fixed.length : c.Passed}</b>
              {model.previous ? (fixed.length ? <ul>{fixed.slice(0, 3).map((t) => <li key={t.Id}>{t.Title}</li>)}</ul> : <span className="mt-muted">Nothing changed to passed.</span>) : <span className="mt-muted">of {plural(c.total, "test")}</span>}
              <Bar tally={c} thin />
            </div>
            <div className="mt-areacard">
              <span className="k">By product (failed)</span>
              {products.map((p) => (
                <div key={String(p.k)} className="mt-prow"><ProductMark product={p.k} size="sm" /><span className="nm">{model.productName(p.k)}</span><span className="track"><i style={{ width: `${(p.c.Failed / maxFailed) * 100}%` }} /></span><b className="mt-num">{p.c.Failed}</b></div>
              ))}
            </div>
          </div>
          {ranked.length > 0 && <FixList rows={ranked} limit={4} />}
          {failing.length > 4 && <a className="mt-link" href="#/tests" onClick={(e) => { e.preventDefault(); explore({ filters: { Result: ["Failed"], Area: current.o.areas } }) }}>All {failing.length} failures here →</a>}
        </div>
      </div>
    </section>
  )
}

/** The objects the tests named, by type, from AffectedObjects. */
export function Checked() {
  const { model } = useReport()
  const { types, reads } = objectsChecked(model)
  if (!types.length) return null
  const total = types.reduce((s, t) => s + t.count, 0)
  return (
    <section className="mt-sec">
      <div className="mt-sechead"><h2 className="mt-h2">What Maester checked</h2><Link to="/affected-objects">All {total} objects →</Link></div>
      <div className="mt-checked">
        {types.map((t) => (
          <Link key={t.type} to="/affected-objects" className="mt-card mt-obj">
            {t.icon ? <img className="mt-fm lg" src={`${ICON_BASE}/features/${t.icon}.svg`} alt="" loading="lazy" referrerPolicy="no-referrer" onError={(e) => { (e.currentTarget as HTMLImageElement).style.visibility = "hidden" }} /> : <span className="mt-fm lg" />}
            <span className="t"><b className="mt-num">{t.count}</b><span>{t.count === 1 ? t.name : t.name.endsWith("y") ? `${t.name.slice(0, -1)}ies` : `${t.name}s`}</span></span>
            {t.failing > 0 && <span className="mt-badge bad">{t.failing} in failing tests</span>}
          </Link>
        ))}
      </div>
      {reads > 0 && <p className="mt-note" style={{ margin: 0 }}>The run also read {plural(reads, "other tenant setting")}, listed under Affected objects.</p>}
    </section>
  )
}
