// The first page. A full run gets the summary: pass rate, what to fix first, products, frameworks, what an
// attacker could do, why tests did not run, and packs. A run of one to three tests gets the tests themselves.

import { Link } from "@/lib/router"
import { REASONS, RESULTS, RESULT_LABEL, SEVERITIES, SEVERITY_MEANING, fixCommand, frameworkLabel, isQuickWin, maesterVersion, serviceName, severityWeight, tally, type Row } from "@/lib/model"
import { useReport } from "@/components/report/ReportContext"
import { DetailBody, DetailHeader, DetailTabs } from "@/components/report/TestDetail"
import { FixList, Footer } from "@/components/report/lists"
import { AttackAreas, Checked, Kpis, Posture, Trend } from "@/components/report/overview"
import { Bar, Cmd, ProductMark, formatDate, plural } from "@/components/report/ui"

const SEVERITY_COLOUR: Record<string, string> = { Critical: "var(--mt-fail)", High: "var(--mt-high)", Medium: "var(--mt-warn)", Low: "var(--mt-skip)", Info: "var(--mt-info)" }

function Ring({ rate, scored }: { rate: number | null; scored: number }) {
  const c = 2 * Math.PI * 62
  return (
    <div className="mt-ring">
      <svg width="148" height="148" viewBox="0 0 148 148" role="img" aria-label={`Pass rate ${rate ?? 0}%`}>
        <circle cx="74" cy="74" r="62" fill="none" stroke="var(--mt-subtle)" strokeWidth="14" />
        {scored > 0 && <circle cx="74" cy="74" r="62" fill="none" stroke="var(--mt-fail)" strokeWidth="14" strokeDasharray={`${c} ${c}`} transform="rotate(-90 74 74)" />}
        {scored > 0 && <circle cx="74" cy="74" r="62" fill="none" stroke="var(--mt-pass)" strokeWidth="14" strokeDasharray={`${(c * (rate ?? 0)) / 100} ${c}`} transform="rotate(-90 74 74)" />}
      </svg>
      <div className="c"><b className="mt-num">{rate ?? "–"}{rate !== null ? "%" : ""}</b><span>passed of {scored}<br />scored tests</span></div>
    </div>
  )
}

function Focused() {
  const { model } = useReport()
  const rows = model.rows
  const first = rows[0]
  const before = model.previous?.Results[first.Id]
  const verdict: Record<string, string> = { Passed: "It passed.", Failed: "It failed.", Investigate: "It needs a closer look.", Error: "It could not run because of an error.", Skipped: "It was skipped.", NotRun: "It did not run." }
  const tenant = String(model.result.TenantName || "the tenant").replace(/\.$/, "")
  const lead = rows.length === 1
    ? `You ran one test against ${tenant}. ${verdict[first.Result] || ""}${before && before !== first.Result && model.previous ? ` It ${before === "Passed" || before === "Failed" ? before.toLowerCase() : `was ${RESULT_LABEL[before]?.toLowerCase()}`} on ${formatDate(model.previous.ExecutedAt)}, so something changed since then.` : ""}`
    : `You ran ${rows.length} tests against ${tenant}: ${RESULTS.filter((r) => model.all[r]).map((r) => `${model.all[r]} ${RESULT_LABEL[r].toLowerCase()}`).join(", ")}.`
  const more: [string, string][] = []
  if (first.Feature) more.push([`Every test for ${model.featureName(first)}`, `Invoke-Maester -Feature ${first.Feature}`])
  if (first.Product && model.hasAttributes) more.push([`Every ${model.productName(first.Product)} test`, `Invoke-Maester -Product ${first.Product}`])
  if (first.Benchmark && first.Suite) more.push([`The whole ${frameworkLabel({ Key: String(first.Benchmark.Framework), Name: String(first.Benchmark.Framework) })} benchmark`, `Invoke-Maester -Suite ${first.Suite}`])
  more.push(["Everything Maester checks", "Invoke-Maester"])
  return (
    <div className="mt-wrap">
      <div className="mt-head">
        <div className="mt-eyebrow">{rows.length === 1 ? "One test" : plural(rows.length, "test")} · {formatDate(model.result.ExecutedAt, true)}</div>
        <h1 className="mt-h1">{rows.length === 1 ? first.Title : `${model.all.Failed} of ${rows.length} tests failed`}</h1>
        <p className="mt-lead">{lead}</p>
      </div>
      <div className="mt-focus">
        <div style={{ display: "flex", flexDirection: "column", gap: 16, minWidth: 0 }}>
          {rows.map((t) => <div key={t.Id} className="mt-panel"><DetailHeader test={t} inline /><DetailTabs test={t} /><DetailBody test={t} /></div>)}
        </div>
        <aside style={{ display: "flex", flexDirection: "column", gap: 14 }}>
          <div className="mt-card mt-pad mt-sec">
            <h2 className="mt-h2">Check more of this tenant</h2>
            <p className="mt-note">The report grows with the run: products, frameworks and the action plan appear once there are more than a few tests.</p>
            {more.map(([label, command]) => <div key={command} style={{ display: "flex", flexDirection: "column", gap: 5 }}><span style={{ fontSize: 13, fontWeight: 550 }}>{label}</span><Cmd command={command} wrap /></div>)}
          </div>
          <div className="mt-card mt-pad mt-sec">
            <h2 className="mt-h2">This run</h2>
            <dl className="mt-kv" style={{ gridTemplateColumns: "1fr" }}>
              {([["Command", model.result.InvokeCommand], ["Duration", model.result.TotalDuration], ["Maester", maesterVersion(model.result)], ["Account", model.result.Account]] as [string, unknown][]).filter(([, v]) => v).map(([k, v]) => <div key={k}><dt>{k}</dt><dd className={k === "Command" ? "mt-mono" : ""} style={k === "Command" ? { fontSize: 11.5 } : undefined}>{String(v)}</dd></div>)}
            </dl>
          </div>
        </aside>
      </div>
      <Footer />
    </div>
  )
}

export default function OverviewPage() {
  const { model, explore } = useReport()
  if (!model.rows.length) return <div className="mt-wrap"><div className="mt-head"><h1 className="mt-h1">No tests ran</h1><p className="mt-lead">The result has no tests. Check the selection in Run details.</p></div></div>
  if (model.focused) return <Focused />

  const { all, failing } = model
  const nSources = new Set(model.rows.map((t) => (t.Package ? t.Package.Id : t.Suite || t.Source))).size
  const highFailing = failing.filter((t) => severityWeight(t.Severity) >= 3 && t.Severity !== "Info").length
  const reach = all.scored ? Math.round(((all.scored - failing.filter((t) => t.Severity !== "Info").length + highFailing) / all.scored) * 100) : null
  const severityCounts = SEVERITIES.map((s) => [s, failing.filter((t) => t.Severity === s).length] as [string, number]).filter(([, n]) => n)
  const maxSeverity = Math.max(1, ...severityCounts.map(([, n]) => n))
  const notRun = model.rows.filter((t) => t.Result === "Skipped" || t.Result === "NotRun" || t.Result === "Error")
  const reasons = new Map<string, { code: string; command: string; rows: Row[] }>()
  for (const t of notRun) {
    const code = t.ReasonCode || (t.Result === "Error" ? "TestError" : "NotApplicable")
    const command = fixCommand({ ...t, ReasonCode: code })
    const key = `${code}|${code === "ServiceNotConnected" ? command : ""}`
    if (!reasons.has(key)) reasons.set(key, { code, command, rows: [] })
    reasons.get(key)!.rows.push(t)
  }
  const reasonRows = [...reasons.values()].sort((a, b) => b.rows.length - a.rows.length).slice(0, 6)
  const notRunCount = all.Skipped + all.NotRun + all.Error

  return (
    <div className="mt-wrap">
      <div className="mt-head">
        <div className="mt-eyebrow">Security report · {formatDate(model.result.ExecutedAt, true)}</div>
        <h1 className="mt-h1">{model.result.TenantName || "The tenant"} passed {all.rate ?? 0}% of the checks that ran</h1>
        <p className="mt-lead">
          {plural(all.total, "test")}{model.hasAttributes ? ` from ${nSources} ${nSources === 1 ? "suite" : "suites and packs"}` : ""} ran{model.products.length ? ` against ${plural(model.products.length, "product")}` : ""}. <b>{all.Failed} failed</b>, {all.Investigate} need a closer look, and {notRunCount} did not run because a service, licence or permission was missing.
          {highFailing > 0 && reach !== null ? <> Fixing the {plural(highFailing, "high-severity failure")} would take the pass rate to <b>{reach}%</b>.</> : null}
        </p>
      </div>

      <Kpis />

      <div className="mt-hero">
        <div className="mt-card mt-pad">
          <div className="mt-score">
            <Ring rate={all.rate} scored={all.scored} />
            <div className="mt-counts">
              {RESULTS.map((r) => <button key={r} type="button" className="mt-count" onClick={() => explore({ filters: { Result: [r] } })}><b className="mt-num">{all[r]}</b><span><i className={`mt-b-${r}`} />{RESULT_LABEL[r]}</span></button>)}
            </div>
          </div>
          {model.previous && (
            <div className="mt-delta">
              <Link to="/changes"><b className="mt-up mt-num">+{model.changes.newlyFailing.length}</b> new failures since {formatDate(model.previous.ExecutedAt)}</Link>
              <Link to="/changes"><b className="mt-down mt-num">{model.changes.fixed.length}</b> fixed</Link>
              <Link to="/changes"><b className="mt-num">{model.changes.added.length}</b> tests added</Link>
            </div>
          )}
          <Trend />
        </div>
        <div className="mt-card mt-pad mt-sec">
          <div className="mt-sechead"><h2 className="mt-h2">Failed by severity</h2>{failing.length >= 2 && <Link to="/plan">Open the action plan →</Link>}</div>
          <div className="mt-sevrows">
            {severityCounts.map(([s, n]) => (
              <button key={s} type="button" className="mt-sevrow" onClick={() => explore({ filters: { Result: ["Failed"], Severity: [s] } })}>
                <span className={`mt-sev mt-s-${s}`}>{s}</span><span className="track"><i style={{ width: `${(n / maxSeverity) * 100}%`, background: SEVERITY_COLOUR[s] }} /></span><b className="mt-num" style={{ textAlign: "right" }}>{n}</b>
              </button>
            ))}
            {!severityCounts.length && <p className="mt-note">Nothing failed.</p>}
          </div>
          {severityCounts.length > 0 && <dl className="mt-sevdef">{severityCounts.flatMap(([s]) => [<dt key={`t${s}`}>{s}</dt>, <dd key={`d${s}`}>{SEVERITY_MEANING[s]}</dd>])}</dl>}
          {failing.length > 0 && <p className="mt-note">{failing.filter(isQuickWin).length} of the {failing.length} failures are quick wins: little effort to fix, and users won't notice.</p>}
        </div>
      </div>

      {failing.length > 0 && (
        <section className="mt-sec">
          <div className="mt-sechead"><h2 className="mt-h2">Fix these first</h2>{failing.length > 6 && <Link to="/plan">All {failing.length} failures, ranked →</Link>}</div>
          <FixList rows={model.ranked} limit={6} />
          <p className="mt-note">Ranked by severity, then by how little the fix costs and how little it disrupts users.</p>
        </section>
      )}

      {model.products.length >= 2 && (
        <section className="mt-sec">
          <div className="mt-sechead"><h2 className="mt-h2">Products</h2><a href="#/tests" onClick={(e) => { e.preventDefault(); explore({ group: "product" }) }}>Compare in the test list →</a></div>
          <div className="mt-grid mt-g3">
            {model.products.map((p) => {
              const c = tally(p.rows)
              const fromPacks = p.rows.filter((t) => t.Package).length
              return (
                <Link key={p.key} to={`/product/${encodeURIComponent(p.key)}`} className="mt-card mt-prod">
                  <div className="top"><ProductMark product={p.key} /><b>{p.name}</b><span className="n">{plural(c.total, "test")}</span></div>
                  <Bar tally={c} />
                  <div className="mt-stats"><span><b className="mt-num">{c.Failed}</b> failed</span><span><b className="mt-num">{c.Passed}</b> passed</span><span><b className="mt-num">{c.Skipped + c.NotRun}</b> not run</span>{c.scored >= 5 && <span style={{ marginLeft: "auto" }}><b className="mt-num">{c.rate}%</b></span>}{fromPacks > 0 && <span style={{ flexBasis: "100%", fontSize: 11.5 }}>{fromPacks} from packs</span>}</div>
                </Link>
              )
            })}
          </div>
        </section>
      )}

      <Posture />

      <AttackAreas />

      <Checked />

      {(notRun.length > 0 || model.packs.length > 0) && (
        <div className="mt-grid mt-g2">
          {notRun.length > 0 && (
            <section className="mt-sec">
              <div className="mt-sechead"><h2 className="mt-h2">Why {plural(notRunCount, "test")} did not run</h2><Link to="/run">Run details →</Link></div>
              <div className="mt-card mt-whylist">
                {reasonRows.map((g) => (
                  <div key={g.code + g.command} className="mt-whyrow">
                    <div>
                      <b>{g.code === "ServiceNotConnected" ? `${serviceName(g.command.replace("Connect-Maester -Service ", ""))} not connected` : (REASONS[g.code] || [g.code])[0]}</b> <span className="mt-muted mt-num">· {plural(g.rows.length, "test")}</span>
                      <p>{(REASONS[g.code] || ["", ""])[1]}</p>
                    </div>
                    {g.command ? <Cmd command={g.command} /> : <button type="button" className="mt-btn" onClick={() => explore({ q: "", filters: { Result: [...new Set(g.rows.map((t) => t.Result))] } })}>Show tests</button>}
                  </div>
                ))}
              </div>
            </section>
          )}
          {model.packs.length > 0 && (
            <section className="mt-sec">
              <div className="mt-sechead"><h2 className="mt-h2">Packs in this run</h2><a href="https://maester.dev/docs/packs" target="_blank" rel="noopener noreferrer">Find more packs ↗</a></div>
              <div className="mt-grid" style={{ gap: 10 }}>
                {model.packs.map((p) => {
                  const c = tally(p.rows)
                  return (
                    <Link key={p.Id} to={`/pack/${encodeURIComponent(p.Id)}`} className="mt-card mt-packcard">
                      <div className="ph"><span className="mt-code">{p.Code}</span><b style={{ fontSize: 14 }}>{p.Name}</b>{p.Version && <span className="mt-muted mt-mono" style={{ fontSize: 11.5, marginLeft: "auto" }}>v{p.Version}</span>}</div>
                      {p.Description && <p>{p.Description}</p>}
                      {p.Status !== "Ready" ? <p>Did not run: {p.Reason}</p> : <Bar tally={c} thin />}
                      <div className="mt-legend"><span>{c.Failed} failed</span><span>{c.Passed} passed</span><span>{plural(c.total, "test")}</span>{p.BuiltIn && <span className="mt-badge">Official</span>}{p.Risk && <span className="mt-badge">{p.Risk} risk</span>}</div>
                    </Link>
                  )
                })}
              </div>
            </section>
          )}
        </div>
      )}
      <Footer />
    </div>
  )
}
