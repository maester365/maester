// One test: a header with the key facts, then tabs, so a long guide never pushes the metadata out of reach.
// Shown in the side sheet, or inline when the run has only a few tests.

import { useEffect, useRef, useState, type KeyboardEvent, type ReactNode } from "react"
import { Markdown } from "@/components/Markdown"
import { Link, useLocation } from "@/lib/router"
import { tenantInitials, tenantName } from "@/lib/tenants"
import { getAttachmentPath, getTestAttachments } from "@/lib/reportAttachments"
import { FRAMEWORK_LABEL, REASONS, RESULT_LABEL, TACTICS, outcomeOf, requirementsOf, splitGuide, type Row } from "@/lib/model"
import { useReport } from "./ReportContext"
import { Cmd, FeatureMark, Icon, Pill, ProductMark, Sev, copyText, formatDate, type IconName } from "./ui"
import { testAsMarkdown } from "./aiText"

function Fact({ icon, label, value }: { icon: IconName; label: string; value: ReactNode }) {
  if (!value) return null
  return <span className="mt-fact"><Icon name={icon} /><span className="k">{label}</span><b>{value}</b></span>
}

function DetailRow({ icon, label, children }: { icon: IconName; label: string; children: ReactNode }) {
  if (children === null || children === undefined || children === "" || (Array.isArray(children) && !children.length)) return null
  return <div className="mt-drow"><Icon name={icon} /><span className="k">{label}</span><span className="v">{children}</span></div>
}

function TestLink({ id }: { id: string }) {
  const { openTest } = useReport()
  return <a href={`#${id}`} className="mt-link" onClick={(e) => { e.preventDefault(); openTest(id) }}>{id}</a>
}

export function DetailHeader({ test, inline }: { test: Row; inline?: boolean }) {
  const { model, multi, tenantIndex } = useReport()
  const pack = model.packOf(test)
  const before = model.previous?.Results[test.Id]
  const tenant = multi ? tenantName(model, tenantIndex) : ""
  const rerun = `Invoke-Maester -TestId ${test.Id}`
  const attachments = getTestAttachments(model.result, { Id: test.Id, ParentId: test.ParentId })
  return (
    <header className="mt-detail-head" style={inline ? { borderBottom: "1px solid var(--mt-line)" } : undefined}>
      <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap", paddingRight: inline ? 0 : 196 }}>
        <Pill result={test.Result} />
        <span className="mt-mono" style={{ fontSize: 12.5, color: "var(--mt-ink-2)" }}>{test.Id}</span>
        {tenant && <span className="mt-chip"><span className="mt-tav" aria-hidden="true">{tenantInitials(tenant)}</span>{tenant}</span>}
        {pack && <span className="mt-chip ember">{pack.Code} pack</span>}
        {before && before !== test.Result && <span className={`mt-badge ${test.Result === "Failed" ? "bad" : "good"}`}>Was {RESULT_LABEL[before]?.toLowerCase() || before} last run</span>}
      </div>
      <h2 id={inline ? undefined : "mt-sheet-title"}>{test.Title}</h2>
      <div className="mt-facts">
        {test.Product && <span className="mt-fact"><ProductMark product={test.Product} size="sm" /><b>{model.productName(test.Product)}</b></span>}
        {test.Feature && <span className="mt-fact"><FeatureMark product={test.Product} feature={test.Feature} /><b>{model.featureName(test)}</b></span>}
        <Fact icon="severity" label="Severity" value={test.Severity} />
        <Fact icon="impact" label="User impact" value={test.UserImpact} />
        <Fact icon="effort" label="Effort" value={test.ImplementationCost} />
        <Fact icon="area" label="Area" value={model.areaName(test.Area)} />
      </div>
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        <Cmd command={rerun} />
        {test.HelpUrl && <a className="mt-btn" href={test.HelpUrl} target="_blank" rel="noopener noreferrer">Docs ↗</a>}
        <button type="button" className="mt-btn" onClick={() => copyText(testAsMarkdown(model, test), "Copied for AI")}>Copy for AI</button>
        {attachments.map((a) => <Link key={a.Id} className="mt-btn" to={getAttachmentPath(a)}>{a.Name} report</Link>)}
      </div>
    </header>
  )
}

function tabsFor(test: Row, tenants: number) {
  const guide = splitGuide(test.Description)
  const tabs: [string, string, IconName, number | null][] = [["finding", "Finding", "finding", null]]
  if (guide.fix || guide.about) tabs.push(["fix", "How to fix", "fix", null])
  if (tenants > 1) tabs.push(["tenants", "Tenants", "tenant", tenants])
  tabs.push(["details", "Details", "tag", null], ["frameworks", "Frameworks", "framework", requirementsOf(test).length], ["attack", "ATT&CK", "attack", test.Mitre.length], ["history", "History", "history", null])
  return tabs
}

export function DetailTabs({ test }: { test: Row }) {
  const { tab, setTab, models } = useReport()
  const tabs = tabsFor(test, models.length)
  const current = tabs.some(([k]) => k === tab) ? tab : "finding"
  const onKey = (e: KeyboardEvent<HTMLButtonElement>) => {
    if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return
    const i = tabs.findIndex(([k]) => k === current) + (e.key === "ArrowRight" ? 1 : -1)
    const next = tabs[(i + tabs.length) % tabs.length][0]
    setTab(next)
    window.setTimeout(() => (e.currentTarget.parentElement?.querySelector(`[data-tab="${next}"]`) as HTMLElement | null)?.focus(), 0)
  }
  return (
    <div className="mt-tabs" role="tablist" aria-label="Test sections">
      {tabs.map(([key, label, icon, n]) => (
        <button key={key} type="button" role="tab" data-tab={key} aria-selected={current === key} tabIndex={current === key ? 0 : -1} onClick={() => setTab(key)} onKeyDown={onKey}>
          <Icon name={icon} />{label}{n ? <span className="n">{n}</span> : null}
        </button>
      ))}
    </div>
  )
}

export function DetailBody({ test }: { test: Row }) {
  const { model, models, tenantIndex, selectTenant, tab } = useReport()
  const { pathname } = useLocation()
  const tabs = tabsFor(test, models.length)
  const current = tabs.some(([k]) => k === tab) ? tab : "finding"
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => { ref.current?.scrollTo(0, 0) }, [current, test.Id])
  const guide = splitGuide(test.Description)
  const outcome = test.Result === "Failed" ? outcomeOf(test) : undefined
  const pack = model.packOf(test)
  const reqs = requirementsOf(test)
  const shims = model.rows.filter((t) => t.ShimOf === test.Id)
  const before = model.previous?.Results[test.Id]

  let body: ReactNode = null
  if (current === "finding") body = (
    <>
      {outcome && <div className="mt-callout"><Icon name="attack" /><span><b>What an attacker could do: {outcome.title.toLowerCase()}.</b> {outcome.text}</span></div>}
      {test.ReasonCode && <div className="mt-callout warn"><span><b>{(REASONS[test.ReasonCode] || [test.ReasonCode])[0]}.</b> {test.ReasonDetail}</span></div>}
      <section><h3>What Maester found</h3>{test.Detail ? <Markdown className="mt-md">{test.Detail}</Markdown> : <p className="mt-note">The test recorded no details.</p>}</section>
      {guide.about && <section><h3>Why it matters</h3><Markdown className="mt-md">{guide.about}</Markdown></section>}
    </>
  )
  else if (current === "fix") body = (
    <>
      <section><h3>How to fix it</h3><Markdown className="mt-md">{guide.fix || guide.about}</Markdown></section>
      <section><h3>Then check it again</h3><Cmd command={`Invoke-Maester -TestId ${test.Id}`} /></section>
    </>
  )
  else if (current === "details") body = (
    <>
      <div className="mt-dgroup"><h4>What it checks</h4>
        <DetailRow icon="product" label="Product">{test.Product ? <span style={{ display: "inline-flex", gap: 7, alignItems: "center" }}><ProductMark product={test.Product} size="sm" />{model.productName(test.Product)}</span> : "Custom test"}</DetailRow>
        <DetailRow icon="related" label="Also affects">{test.RelatedProduct.length ? test.RelatedProduct.map((k) => <span key={k} style={{ display: "inline-flex", gap: 6, alignItems: "center", marginRight: 10 }}><ProductMark product={k} size="sm" />{model.productName(k)}</span>) : null}</DetailRow>
        <DetailRow icon="feature" label="Feature">{test.Feature ? <span style={{ display: "inline-flex", gap: 7, alignItems: "center" }}><FeatureMark product={test.Product} feature={test.Feature} />{model.featureName(test)}</span> : null}</DetailRow>
        <DetailRow icon="area" label="Area">{model.areaName(test.Area)}</DetailRow>
        <DetailRow icon="resource" label="Resource type">{test.ResourceType}</DetailRow>
      </div>
      <div className="mt-dgroup"><h4>Impact</h4>
        <DetailRow icon="severity" label="Severity"><Sev severity={test.Severity} /></DetailRow>
        <DetailRow icon="impact" label="User impact">{test.UserImpact}</DetailRow>
        <DetailRow icon="effort" label="Effort to fix">{test.ImplementationCost}</DetailRow>
      </div>
      <div className="mt-dgroup"><h4>How it runs</h4>
        <DetailRow icon="service" label="Connects to">{test.Service.join(", ")}</DetailRow>
        <DetailRow icon="licence" label="Licence">{test.License.length ? test.License.join(", ") : model.hasAttributes ? "None required" : null}</DetailRow>
        <DetailRow icon="permission" label="Permissions">{test.Permission.join(", ")}</DetailRow>
        <DetailRow icon="params" label="Parameters">{test.Parameters.length ? test.Parameters.map((p) => `${p.Name} = ${typeof p.Value === "object" ? JSON.stringify(p.Value) : String(p.Value)}`).join("; ") : null}</DetailRow>
        <DetailRow icon="duration" label="Duration">{test.Duration}</DetailRow>
        <DetailRow icon="lifecycle" label="Lifecycle">{test.Lifecycle}{test.ReplacedBy ? <> · replaced by <TestLink id={test.ReplacedBy} /></> : null}</DetailRow>
      </div>
      <div className="mt-dgroup"><h4>Where it comes from</h4>
        <DetailRow icon="source" label="Suite">{test.Suite || test.Source}</DetailRow>
        <DetailRow icon="pack" label="Pack">{pack ? <>{pack.Name} <span className="mt-mono mt-muted">v{pack.Version}</span></> : null}</DetailRow>
        <DetailRow icon="shim" label="Same check as">{test.ShimOf ? <TestLink id={test.ShimOf} /> : null}</DetailRow>
        <DetailRow icon="shim" label="Also reported as">{shims.length ? shims.map((s, i) => <span key={s.Id}>{i ? ", " : ""}<TestLink id={s.Id} /></span>) : null}</DetailRow>
        <DetailRow icon="tag" label="Tags">{test.Tag.join(", ")}</DetailRow>
      </div>
    </>
  )
  else if (current === "frameworks") body = reqs.length ? (
    <>
      <div className="mt-links">{reqs.map(([key, id]) => {
        const fw = model.frameworks.find((f) => f.Key === key)
        const facts = test.Benchmark && test.Benchmark.Framework === key ? [test.Benchmark.Level, test.Benchmark.Criticality].filter(Boolean).join(" · ") : ""
        const label = <><span style={{ display: "inline-flex", gap: 8, alignItems: "center" }}><Icon name="framework" />{FRAMEWORK_LABEL[key] || fw?.Name || key}{facts ? ` · ${facts}` : ""}</span><span>{id}</span></>
        return fw ? <Link key={key + id} to={`/framework/${encodeURIComponent(key)}`}>{label}</Link> : <div key={key + id}>{label}</div>
      })}</div>
      <p className="mt-note">A passed test shows the setting is in place. On its own it does not show that the tenant meets the framework.</p>
    </>
  ) : <p className="mt-note">This test is not mapped to a framework.</p>
  else if (current === "attack") body = test.Mitre.length ? (
    <div className="mt-links">{test.Mitre.map((m) => {
      const t = model.technique(m)
      return <div key={m}><span style={{ display: "inline-flex", gap: 8, alignItems: "center" }}><Icon name="attack" />{t.Name} <span className="mt-muted" style={{ fontSize: 12 }}>{t.Tactics.map((x) => (TACTICS.find((y) => y[0] === x) || [x, x])[1]).join(", ")}</span></span><span>{m}</span></div>
    })}</div>
  ) : <p className="mt-note">This test is not mapped to an ATT&amp;CK technique.</p>
  else if (current === "tenants") {
    const results = models.map((m) => m.byId.get(test.Id))
    const failed = results.filter((t) => t?.Result === "Failed").length
    const ran = results.filter((t) => t?.Result === "Failed" || t?.Result === "Passed").length
    body = (
      <>
        <p className="mt-note" style={{ margin: 0 }}>{failed ? `Fails in ${failed} of the ${ran} tenants it ran in.` : `Passes in every tenant it ran in.`} Select a tenant to see its finding.</p>
        <div className="mt-links">
          {models.map((m, i) => {
            const t = results[i]
            const name = tenantName(m, i)
            const label = <><span className="mt-tname"><span className="mt-tav" aria-hidden="true">{tenantInitials(name)}</span><span>{name}{i === tenantIndex ? <span className="mt-muted"> · shown</span> : null}</span></span>{t ? <Pill result={t.Result} /> : <span className="mt-muted">Not in this run</span>}</>
            return t && i !== tenantIndex
              ? <button key={i} type="button" onClick={() => selectTenant(i, { pathname, hash: `#${encodeURIComponent(test.Id)}` })}>{label}</button>
              : <div key={i} aria-current={i === tenantIndex ? "true" : undefined}>{label}</div>
          })}
        </div>
      </>
    )
  }
  else if (current === "history") body = (
    <>
      <div className="mt-links">
        <div><span>{formatDate(model.result.ExecutedAt)} · this run</span><Pill result={test.Result} /></div>
        {model.previous && <div><span>{formatDate(model.previous.ExecutedAt)} · previous run</span>{before ? <Pill result={before} /> : <span className="mt-muted">Not run</span>}</div>}
      </div>
      <p className="mt-note">{model.previous ? `Compared with ${model.previous.File || "the previous result"} in the output folder.` : "No earlier result for this tenant was found in the output folder."}</p>
    </>
  )
  return <div ref={ref} className="mt-detail-body" role="tabpanel">{body}</div>
}

// Keys that belong to what has focus: typing in a field, or the arrow keys of the tabs.
const ownKeys = (target: EventTarget | null) => target instanceof HTMLElement && (target.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName) || target.getAttribute("role") === "tab")

/** The test as a side sheet over the current view. */
export function TestSheet() {
  const { model, openId, openTest, sequence, closeTest } = useReport()
  const test = openId ? model.byId.get(openId) : undefined
  const at = test ? sequence.indexOf(test.Id) : -1
  const prev = at > 0 ? sequence[at - 1] : null
  const next = at >= 0 && at < sequence.length - 1 ? sequence[at + 1] : null
  const step = (id: string | null) => { if (id) openTest(id, sequence, true) }
  const closeRef = useRef<HTMLButtonElement>(null)
  // Full screen or beside the view. The choice is remembered for the next test, in this browser only.
  const [max, setMax] = useState(() => { try { return localStorage.getItem("mt-sheet-max") === "1" } catch { return false } })
  const toggleMax = () => setMax((m) => { try { localStorage.setItem("mt-sheet-max", m ? "0" : "1") } catch { /* storage refused */ } return !m })
  useEffect(() => { if (test) closeRef.current?.focus() }, [test?.Id])
  useEffect(() => {
    if (!test) return
    const onKey = (e: globalThis.KeyboardEvent) => {
      if (e.key === "Escape") { closeTest(); return }
      if (e.metaKey || e.ctrlKey || e.altKey || ownKeys(e.target)) return
      const id = e.key === "ArrowLeft" || e.key === "k" ? prev : e.key === "ArrowRight" || e.key === "j" ? next : undefined
      if (id === undefined) return
      e.preventDefault()
      step(id)
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  })
  // The page behind the sheet stays put while the sheet scrolls.
  useEffect(() => {
    if (!test) return
    document.documentElement.classList.add("mt-locked")
    return () => document.documentElement.classList.remove("mt-locked")
  }, [!!test])
  if (!test) return null
  return (
    <>
      <div className="mt-scrim" onClick={closeTest} />
      <aside className={`mt-sheet${max ? " max" : ""}`} role="dialog" aria-modal="true" aria-labelledby="mt-sheet-title">
        <div className="mt-sheet-btns">
          {sequence.length > 1 && at >= 0 && <>
            <span className="mt-sheet-pos mt-hide-sm" aria-live="polite">{at + 1} of {sequence.length}</span>
            <button type="button" className="mt-btn icon" onClick={() => step(prev)} disabled={!prev} aria-label="Previous test" title="Previous test (← or K)"><Icon name="prev" /></button>
            <button type="button" className="mt-btn icon" onClick={() => step(next)} disabled={!next} aria-label="Next test" title="Next test (→ or J)"><Icon name="next" /></button>
          </>}
          <button type="button" className="mt-btn icon mt-hide-sm" onClick={toggleMax} aria-label={max ? "Restore" : "Maximize"} title={max ? "Restore" : "Maximize"} aria-pressed={max}><Icon name={max ? "restore" : "maximize"} /></button>
          <button ref={closeRef} type="button" className="mt-btn icon" onClick={closeTest} aria-label="Close" title="Close"><Icon name="close" /></button>
        </div>
        <DetailHeader test={test} />
        <DetailTabs test={test} />
        <DetailBody test={test} />
      </aside>
    </>
  )
}
