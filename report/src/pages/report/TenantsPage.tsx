// A merged result of several tenants: how each tenant did, each product in each tenant, the failures to fix once
// for every tenant, the failures only one tenant has, and each framework in each tenant. Everything links into
// that tenant's own views.

import { useMemo, useState } from "react"
import { REASONS, frameworkLabel, frameworkRank, frameworkTally, serviceName, severityWeight, tally, type Framework } from "@/lib/model"
import { useReport } from "@/components/report/ReportContext"
import { Footer } from "@/components/report/lists"
import { Bar, Icon, ProductMark, Sev, formatDate, plural } from "@/components/report/ui"
import { band, crossTests, failingInMost, failingInOne, tenantInitials, tenantName, type CrossTest } from "@/lib/tenants"
import { Segmented } from "./ProductPage"
import { Trend } from "@/components/report/overview"
import { runHistory } from "@/lib/insights"

const DAY = 86400000

function Avatar({ name, large }: { name: string; large?: boolean }) {
  return <span className={`mt-tav${large ? " lg" : ""}`} aria-hidden="true">{tenantInitials(name)}</span>
}

export default function TenantsPage() {
  const { models, selectTenant } = useReport()
  const [list, setList] = useState<"most" | "one">("most")
  const [showAll, setShowAll] = useState(false)
  const names = models.map((m, i) => tenantName(m, i))
  const tallies = models.map((m) => m.all)
  const cross = useMemo(() => crossTests(models), [models])
  const most = useMemo(() => failingInMost(cross), [cross])
  const one = useMemo(() => failingInOne(cross), [cross])

  const rates = tallies.map((t) => t.rate ?? 0)
  const low = rates.indexOf(Math.min(...rates))
  const dates = models.map((m) => new Date(m.result.ExecutedAt).getTime()).filter((d) => !Number.isNaN(d))
  const newest = Math.max(...dates)
  const oldest = Math.min(...dates)

  // Things that make tenants hard to compare: a run much older than the others, and a service a tenant did not
  // connect to while others did (a service no tenant connected to leaves every score alike).
  const warnings: string[] = []
  // A service counts as missing only when none of the tenant's tests for it ran: a test that needs Exchange Online
  // and Graph is skipped for Exchange alone.
  const missing = models.map((m) => {
    const counts = new Map<string, number>()
    const ran = new Set(m.rows.filter((t) => t.Result !== "Skipped" && t.Result !== "NotRun").flatMap((t) => t.Service))
    for (const t of m.rows) if (t.ReasonCode === "ServiceNotConnected") for (const s of t.Service) if (!ran.has(s)) counts.set(s, (counts.get(s) || 0) + 1)
    return counts
  })
  models.forEach((m, i) => {
    const age = Math.round((newest - new Date(m.result.ExecutedAt).getTime()) / DAY)
    if (age >= 7) warnings.push(`${names[i]} ran ${age} days before the newest run, so its results may be out of date.`)
    const gaps = [...missing[i]].filter(([s, n]) => n - Math.min(...missing.map((c) => c.get(s) || 0)) >= 10).map(([s]) => serviceName(s))
    if (gaps.length) warnings.push(`${names[i]} did not connect to ${gaps.join(", ").replace(/, ([^,]*)$/, " or $1")}, which other tenants did, so its scores leave ${gaps.length === 1 ? "it" : "them"} out.`)
  })

  // Products in any tenant, in the order the first tenant that has them lists them; frameworks in their usual order.
  const products: { key: string; name: string }[] = []
  for (const m of models) for (const p of m.products) if (!products.some((x) => x.key === p.key)) products.push({ key: p.key, name: p.name })
  const frameworks: Framework[] = []
  for (const m of models) for (const f of m.frameworks) if (!frameworks.some((x) => x.Key === f.Key)) frameworks.push(f)
  frameworks.sort((a, b) => frameworkRank(a.Key) - frameworkRank(b.Key))

  const rows: CrossTest[] = list === "most" ? most : one
  const shown = showAll ? rows : rows.slice(0, 12)
  const order = models.map((_, i) => i).sort((a, b) => (tallies[a].rate ?? 0) - (tallies[b].rate ?? 0))

  return (
    <div className="mt-wrap">
      <div className="mt-head">
        <div className="mt-eyebrow">Multi-tenant report · {plural(models.length, "tenant")} · {formatDate(new Date(oldest).toISOString())}{newest - oldest > DAY ? ` to ${formatDate(new Date(newest).toISOString())}` : ""}</div>
        <h1 className="mt-h1">Your tenants passed between {Math.min(...rates)}% and {Math.max(...rates)}% of their checks</h1>
        <p className="mt-lead">
          {names[low]} is lowest, with {plural(tallies[low].Failed, "failure")}. <b>{plural(most.length, "test")} fail in most tenants</b>: fix each once and roll the change out to every tenant. {one.length > 0 && <>{plural(one.length, "test")} fail in one tenant only, which usually means a setting was changed there.</>}
        </p>
      </div>

      {warnings.length > 0 && (
        <div className="mt-callout warn" role="note"><Icon name="severity" /><div><b>Compare with care.</b><ul className="mt-warnlist">{warnings.map((w) => <li key={w}>{w}</li>)}</ul></div></div>
      )}

      <section className="mt-sec">
        <div className="mt-sechead"><h2 className="mt-h2">Tenants</h2><span className="mt-note">Lowest pass rate first. Select a tenant to open its report.</span></div>
        <div className="mt-tablewrap">
          <table className="mt-table mt-tenants">
            <thead><tr><th>Tenant</th><th>Pass rate</th><th>Trend</th><th>Failed</th><th>Critical and high</th><th>Not run</th><th>Since last run</th><th>Ran</th></tr></thead>
            <tbody>
              {order.map((i) => {
                const m = models[i]
                const c = tallies[i]
                const severe = m.failing.filter((t) => severityWeight(t.Severity) >= 3 && t.Severity !== "Info").length
                return (
                  <tr key={i} className="click" tabIndex={0} onClick={() => selectTenant(i, "/")} onKeyDown={(e) => { if (e.key === "Enter") selectTenant(i, "/") }}>
                    <td><span className="mt-tname"><Avatar name={names[i]} large /><span className="stack"><b>{names[i]}</b><small className="mt-mono">{String(m.result.TenantId || "")}</small></span></span></td>
                    <td><span className="mt-trate"><Bar tally={c} thin /><b className="mt-num">{c.rate ?? "–"}%</b></span></td>
                    <td>{runHistory(m).length > 1 ? <Trend points={runHistory(m)} compact /> : <span className="mt-muted">First run</span>}</td>
                    <td className="mt-num"><b>{c.Failed}</b></td>
                    <td className="mt-num">{severe ? <span className="mt-badge bad">{severe}</span> : <span className="mt-muted">0</span>}</td>
                    <td className="mt-num">{c.Skipped + c.NotRun + c.Error}</td>
                    <td className="mt-num">{m.previous ? <span className="mt-chg"><span className="mt-up">+{m.changes.newlyFailing.length}</span><span className="mt-down">−{m.changes.fixed.length}</span></span> : <span className="mt-muted">First run</span>}</td>
                    <td className="mt-muted" style={{ whiteSpace: "nowrap" }}>{formatDate(m.result.ExecutedAt)}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </section>

      {products.length > 0 && (
        <section className="mt-sec">
          <div className="mt-sechead"><h2 className="mt-h2">Products in each tenant</h2><span className="mt-note">Pass rate of the scored tests. Select a cell to open that product in that tenant.</span></div>
          <div className="mt-tablewrap">
            <table className="mt-table mt-heatgrid">
              <thead><tr><th>Tenant</th>{products.map((p) => <th key={p.key} title={p.name}><span className="mt-hp"><ProductMark product={p.key} size="sm" /><span>{p.name}</span></span></th>)}</tr></thead>
              <tbody>
                {models.map((m, i) => (
                  <tr key={i}>
                    <th scope="row"><span className="mt-tname"><Avatar name={names[i]} /><span className="stack"><b>{names[i]}</b></span></span></th>
                    {products.map((p) => {
                      const prod = m.products.find((x) => x.key === p.key)
                      const c = prod ? tally(prod.rows) : null
                      const rate = c && c.scored ? c.rate : null
                      return (
                        <td key={p.key}>
                          {prod ? (
                            <button type="button" className="mt-heat" data-band={band(rate)} onClick={() => selectTenant(i, `/product/${encodeURIComponent(p.key)}`)} aria-label={`${p.name} in ${names[i]}: ${rate === null ? "nothing scored" : `${rate}% passed`}, ${c!.Failed} failed`}>
                              {rate === null ? "–" : `${rate}%`}<small>{c!.Failed} failed</small>
                            </button>
                          ) : <span className="mt-heat" data-band="none">Not run</span>}
                        </td>
                      )
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-legend mt-heatkey"><span><i data-band="4" />90% or more</span><span><i data-band="3" />75–89%</span><span><i data-band="2" />60–74%</span><span><i data-band="1" />40–59%</span><span><i data-band="0" />Under 40%</span></div>
        </section>
      )}

      <section className="mt-sec">
        <div className="mt-sechead">
          <h2 className="mt-h2">{list === "most" ? "Fix once, roll out everywhere" : "Out of line with the other tenants"}</h2>
          <Segmented label="Which failures" value={list} onChange={(v) => { setList(v as "most" | "one"); setShowAll(false) }} options={[["most", `Fails in most · ${most.length}`], ["one", `Fails in one · ${one.length}`]]} />
        </div>
        <p className="mt-note" style={{ margin: 0 }}>{list === "most" ? "Tests that fail in most of the tenants they ran in, worst first. One change, scripted or set in a template, fixes them all." : "Tests that fail in one tenant while others pass. Compare that tenant's setting with the others."}</p>
        {rows.length ? (
          <div className="mt-tablewrap">
            <table className="mt-table mt-cross">
              <thead><tr><th>Severity</th><th>Test</th>{names.map((n, i) => <th key={i} className="t" title={n}><Avatar name={n} /></th>)}<th className="t">Fails in</th></tr></thead>
              <tbody>
                {shown.map((c) => (
                  <tr key={c.id}>
                    <td><Sev severity={c.test.Severity} /></td>
                    <td className="ttl"><span className="mt-mono mt-muted" style={{ fontSize: 11.5 }}>{c.id}</span><br />{c.test.Title}</td>
                    {c.results.map((r, i) => (
                      <td key={i} className="t">
                        {r ? <button type="button" className={`mt-dot mt-b-${r.Result}`} title={`${names[i]}: ${r.Result}${r.ReasonCode ? ` (${(REASONS[r.ReasonCode] || [r.ReasonCode])[0]})` : ""}`} aria-label={`${names[i]}: ${r.Result}. Open the test in this tenant.`} onClick={() => selectTenant(i, { pathname: "/tenants", hash: `#${encodeURIComponent(c.id)}` })} />
                          : <span className="mt-dot empty" title={`${names[i]}: not in this run`} />}
                      </td>
                    ))}
                    <td className="t mt-num"><b>{c.failed}</b><span className="mt-muted">/{c.ran}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : <p className="mt-empty">No test fits.</p>}
        <div className="mt-legend"><span><i className="mt-b-Passed" />Passed</span><span><i className="mt-b-Failed" />Failed</span><span><i className="mt-b-Investigate" />Investigate</span><span><i className="mt-b-Skipped" />Skipped or not run</span><span className="mt-muted">Select a square to open the test in that tenant.</span></div>
        {rows.length > shown.length && <button type="button" className="mt-btn" style={{ alignSelf: "flex-start" }} onClick={() => setShowAll(true)}>Show all {rows.length}</button>}
      </section>

      {frameworks.length > 0 && (
        <section className="mt-sec">
          <div className="mt-sechead"><h2 className="mt-h2">Frameworks in each tenant</h2><span className="mt-note">Requirements met of those Maester tested. A requirement is met when every test for it passes.</span></div>
          <div className="mt-tablewrap">
            <table className="mt-table mt-heatgrid">
              <thead><tr><th>Framework</th>{names.map((n, i) => <th key={i} title={n}><span className="mt-hp"><Avatar name={n} /><span>{n}</span></span></th>)}</tr></thead>
              <tbody>
                {frameworks.map((f) => (
                  <tr key={f.Key}>
                    <th scope="row"><b>{frameworkLabel(f)}</b></th>
                    {models.map((m, i) => {
                      const mf = m.frameworks.find((x) => x.Key === f.Key)
                      if (!mf) return <td key={i}><span className="mt-heat" data-band="none">Not run</span></td>
                      const c = frameworkTally(m, mf)
                      const tested = c.Passed + c.Failed
                      const rate = tested ? Math.round((c.Passed / tested) * 100) : null
                      return (
                        <td key={i}>
                          <button type="button" className="mt-heat" data-band={band(rate)} onClick={() => selectTenant(i, `/framework/${encodeURIComponent(f.Key)}`)} aria-label={`${frameworkLabel(f)} in ${names[i]}: ${c.Passed} of ${tested} met`}>
                            {rate === null ? "–" : `${rate}%`}<small>{c.Passed}/{tested} met</small>
                          </button>
                        </td>
                      )
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
      <Footer />
    </div>
  )
}
