// The frame of every page: top bar (tenant, search, Ask AI, export, theme), the sidebar built from the views,
// the main column, the test sheet and the toast.

import { useEffect, useMemo, useRef, useState, type ReactNode } from "react"
import { useTheme } from "@/components/ThemeProvider"
import { Link, takeKeepScroll, useLocation, useNavigate } from "@/lib/router"
import { buildPlan, loadWorkshop, workshopAttachment, WORKSHOP_ATTACHMENT, type Plan, type Workshop } from "@/lib/zeroTrust"
import type { Model } from "@/lib/model"
import type { NavEntry } from "@/lib/packNav"
import { reportHeading } from "@/lib/runSubject"
import { useReport } from "./ReportContext"
import { TestSheet } from "./TestDetail"
import { buildNav, locate } from "./nav"
import { Crumbs, NavContext, Sidebar, useNavPages } from "./Sidebar"
import { failuresCsv, failuresMarkdown, summaryMarkdown, tenantsMarkdown } from "./aiText"
import claudeIcon from "@/assets/ai-icons/claude.svg"
import chatgptIcon from "@/assets/ai-icons/chatgpt.svg"
import copilotIcon from "@/assets/ai-icons/copilot.svg"

// Ask AI copies the results and opens a new chat to paste them into. The results never go into the link: a link
// is logged and has a length limit, and Copilot drops a prompt passed in its link when it asks the user to sign in.
const ASSISTANTS = [
  { name: "Claude", icon: claudeIcon, url: "https://claude.ai/new" },
  { name: "ChatGPT", icon: chatgptIcon, url: "https://chatgpt.com/" },
  { name: "Microsoft 365 Copilot", icon: copilotIcon, url: "https://m365.cloud.microsoft/chat" },
]

function AskAi({ onClose }: { onClose: () => void }) {
  const { model, models, multi } = useReport()
  const { pathname } = useLocation()
  const all = multi && pathname === "/tenants"
  const [what, setWhat] = useState<"summary" | "failures">("summary")
  const text = () => (all ? tenantsMarkdown(models) : what === "summary" ? summaryMarkdown(model) : failuresMarkdown(model))
  const paste = /Mac|iPhone|iPad/.test(navigator.platform) ? "⌘V" : "Ctrl+V"
  return (
    <>
      <p>Copy the results, then paste them ({paste}) into a new chat. Remove anything you may not share first, and use the assistant your organisation approves for tenant data.</p>
      {all ? <p className="mt-note" style={{ margin: 0 }}>Copies every tenant's pass rate and the failures they share.</p> : (
        <div className="mt-seg" role="group" aria-label="What to copy">
          <button type="button" aria-pressed={what === "summary"} onClick={() => setWhat("summary")}>Summary</button>
          <button type="button" aria-pressed={what === "failures"} onClick={() => setWhat("failures")}>Every failure · {model.failing.length}</button>
        </div>
      )}
      <div className="opt">
        {ASSISTANTS.map((a) => (
          <a key={a.name} href={a.url} target="_blank" rel="noopener noreferrer" onClick={() => { copyText(text(), `Copied. Paste it into ${a.name} with ${paste}`); onClose() }}>
            <span className="mt-aiapp"><img src={a.icon} alt="" width="18" height="18" /><b>{a.name}</b></span><small>copy and open</small>
          </a>
        ))}
        <button type="button" onClick={() => { copyText(text(), "Copied"); onClose() }}><span className="mt-aiapp"><span className="mt-aiapp-i"><Icon name="report" /></span><b>Copy only</b></span><small>{all ? "every tenant" : what === "summary" ? "top 25 failures, frameworks" : `${model.failing.length} tests with guidance`}</small></button>
      </div>
    </>
  )
}
import { Flame, Icon, Pill, Toaster, copyText, formatDate, tenantLogo } from "./ui"
import { tenantInitials, tenantName } from "@/lib/tenants"

function SearchPalette({ onClose }: { onClose: () => void }) {
  const { model, openTest } = useReport()
  const views = useNavPages()
  const navigate = useNavigate()
  const [q, setQ] = useState("")
  const [sel, setSel] = useState(0)
  const input = useRef<HTMLInputElement>(null)
  useEffect(() => { input.current?.focus() }, [])
  const items = useMemo(() => {
    const query = q.toLowerCase().trim()
    const v = views.filter((x) => !query || `${x.title} ${x.sub}`.toLowerCase().includes(query)).slice(0, query ? 6 : 8).map((x) => ({ kind: "view" as const, key: x.path, title: x.title, sub: x.sub, result: "" }))
    const t = query ? model.rows.filter((r) => `${r.Id} ${r.Title} ${r.Mitre.join(" ")} ${r.Control.join(" ")}`.toLowerCase().includes(query)).slice(0, 12).map((r) => ({ kind: "test" as const, key: r.Id, title: r.Title, sub: r.Id, result: r.Result })) : []
    return [...v, ...t]
  }, [q, views, model])
  const pick = (i: number) => {
    const item = items[i]
    if (!item) return
    onClose()
    if (item.kind === "view") navigate(item.key)
    else openTest(item.key)
  }
  return (
    <div className="mt-pal" onClick={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className="box" role="dialog" aria-label="Search">
        <input ref={input} value={q} placeholder="Search tests, views, controls and techniques" aria-label="Search" autoComplete="off"
          onInput={(e) => { setQ((e.target as HTMLInputElement).value); setSel(0) }}
          onKeyDown={(e) => {
            if (e.key === "ArrowDown") { setSel((s) => Math.min(s + 1, items.length - 1)); e.preventDefault() }
            else if (e.key === "ArrowUp") { setSel((s) => Math.max(s - 1, 0)); e.preventDefault() }
            else if (e.key === "Enter") pick(sel)
            else if (e.key === "Escape") onClose()
          }} />
        <ul>
          {items.length ? items.map((item, i) => (
            <li key={item.kind + item.key}><button type="button" data-on={i === sel} onClick={() => pick(i)}>
              {item.result ? <Pill result={item.result} /> : <span className="mt-badge">View</span>}<span>{item.title}</span><span className="k">{item.sub}</span>
            </button></li>
          )) : <li className="mt-empty">Nothing matches.</li>}
        </ul>
      </div>
    </div>
  )
}

function Popover({ title, children, onClose, left }: { title: string; children: ReactNode; onClose: () => void; left?: boolean }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") onClose() }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [onClose])
  return (
    <>
      <div style={{ position: "fixed", inset: 0, zIndex: 44 }} onClick={onClose} />
      <div className={`mt-pop${left ? " left" : ""}`} role="dialog" aria-label={title}><h3>{title}</h3>{children}</div>
    </>
  )
}

// The attachment names of the plans the packs' menus list, and the workshop plan a pack's default menu lists.
function planNames(model: Model) {
  const names = new Set<string>([WORKSHOP_ATTACHMENT])
  const walk = (es: NavEntry[]) => { for (const e of es) { if (e.View === "plan" && e.Attachment) names.add(e.Attachment); if (e.Items) walk(e.Items) } }
  for (const p of model.packs) if (p.Navigation) walk(p.Navigation)
  return [...names].filter((n) => workshopAttachment(model, n))
}

/** The plans in this result, built with its results once each is read, so the menu can list their pillars. */
function usePlans(model: Model): Map<string, Plan> {
  const names = useMemo(() => planNames(model), [model])
  const [workshops, setWorkshops] = useState<Map<string, Workshop>>(() => new Map())
  useEffect(() => {
    let live = true
    for (const n of names) {
      const a = workshopAttachment(model, n)
      if (a) loadWorkshop(a).then((w) => { if (live) setWorkshops((m) => (m.get(n) === w ? m : new Map(m).set(n, w))) }, () => { /* the plan page says why */ })
    }
    return () => { live = false }
  }, [names, model])
  return useMemo(() => new Map([...workshops].filter(([n]) => names.includes(n)).map(([n, w]) => [n, buildPlan(w, model)])), [workshops, names, model])
}

export function Shell({ children, flush }: { children: ReactNode; flush?: boolean }) {
  const { model, models, multi, tenantIndex, selectTenant } = useReport()
  const { resolvedTheme, setTheme } = useTheme()
  const { pathname, hash } = useLocation()
  const navigate = useNavigate()
  const [navOpen, setNavOpen] = useState(false)
  const [overlay, setOverlay] = useState<"" | "search" | "ai" | "export" | "tenant">("")
  const onTenants = pathname === "/tenants"
  const close = () => setOverlay("")
  const r = model.result
  const heading = reportHeading(model)

  const plans = usePlans(model)
  const nav = useMemo(() => buildNav(model, {
    affectedObjects: Array.isArray(r.AffectedObjects) && r.AffectedObjects.length > 0,
    tenants: models.length,
    plans,
  }), [model, models, r, plans])
  const here = useMemo(() => locate(nav, pathname), [nav, pathname])
  const navState = useMemo(() => ({ nav, here, plans }), [nav, here, plans])
  const collapseRef = useRef<(() => void) | null>(null)
  const narrow = () => typeof matchMedia === "function" && matchMedia("(max-width: 900px)").matches

  // A merged result of several tenants opens on the page that compares them.
  useEffect(() => {
    if (multi && pathname === "/" && !hash) navigate("/tenants", { replace: true })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") { e.preventDefault(); setOverlay("search") } }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [])
  useEffect(() => { if (takeKeepScroll()) return; document.getElementById("report-main")?.scrollTo(0, 0); window.scrollTo(0, 0) }, [pathname])

  return (
    <div className="mt-app">
      <header className="mt-top">
        <button type="button" className="mt-btn icon mt-menu-btn" onClick={() => (narrow() ? setNavOpen((o) => !o) : collapseRef.current?.())} aria-label="Show or hide the menu" title="Show or hide the menu  [" aria-expanded={navOpen}><Icon name="menu" /></button>
        <Link to="/" className="mt-brand" aria-label="Maester report home"><Flame />Maester <small>Report</small></Link>
        <div className="mt-tenant">
          {multi ? (
            <button type="button" className="mt-btn mt-tenant-btn" onClick={() => setOverlay("tenant")} aria-haspopup="dialog">
              {onTenants ? <><Icon name="tenant" /><b>All tenants</b><span className="mt-badge">{models.length}</span></> : <><span className="mt-tav" aria-hidden="true">{tenantInitials(tenantName(model, tenantIndex))}</span><b>{tenantName(model, tenantIndex)}</b></>}
              <Icon name="chevron" />
            </button>
          ) : heading.bar && <b>{heading.bar}</b>}
          {r.ExecutedAt && !onTenants && <span>{formatDate(r.ExecutedAt)}</span>}
        </div>
        <div className="mt-grow" />
        <button type="button" className="mt-btn mt-search" onClick={() => setOverlay("search")}><Icon name="search" /><span>Search tests, controls, techniques</span><kbd>⌘K</kbd></button>
        <button type="button" className="mt-btn mt-hide-sm" onClick={() => setOverlay("ai")}><Icon name="sparkle" />Ask AI</button>
        <button type="button" className="mt-btn mt-hide-sm" onClick={() => setOverlay("export")}>Export</button>
        {!onTenants && tenantLogo(r) && <img className="mt-logo mt-hide-sm" src={tenantLogo(r)} alt={String(r.TenantName || "Organisation")} />}
        <button type="button" className="mt-btn icon" onClick={() => setTheme(resolvedTheme === "dark" ? "light" : "dark")} aria-label="Switch between light and dark"><Icon name="moon" /></button>
      </header>
      <NavContext.Provider value={navState}>
        <div className="mt-shell">
          <Sidebar drawer={navOpen} onNavigate={() => setNavOpen(false)} collapseRef={collapseRef} />
          {navOpen && <div className="mt-navscrim" onClick={() => setNavOpen(false)} />}
          <main id="report-main" className={`mt-main${flush ? " flush" : ""}`}><Crumbs flush={flush} />{children}</main>
        </div>
        {overlay === "search" && <SearchPalette onClose={close} />}
      </NavContext.Provider>
      <TestSheet />
      {overlay === "tenant" && (
        <Popover title="Switch tenant" onClose={close} left>
          <div className="opt">
            <Link to="/tenants" onClick={close} aria-current={onTenants ? "page" : undefined}><span className="mt-tname"><Icon name="tenant" /><b>All tenants</b></span><small>compare {models.length}</small></Link>
            {models.map((m, i) => {
              const name = tenantName(m, i)
              return (
                <button key={i} type="button" aria-current={!onTenants && i === tenantIndex ? "page" : undefined} onClick={() => { close(); selectTenant(i, onTenants ? "/" : { pathname, hash }) }}>
                  <span className="mt-tname"><span className="mt-tav" aria-hidden="true">{tenantInitials(name)}</span><b>{name}</b></span><small>{m.all.rate ?? "–"}% · {m.all.Failed} failed</small>
                </button>
              )
            })}
          </div>
        </Popover>
      )}
      {overlay === "ai" && (
        <Popover title="Ask AI about this report" onClose={close}>
          <AskAi onClose={close} />
        </Popover>
      )}
      {overlay === "export" && (
        <Popover title="Export" onClose={close}>
          <p>Maester also wrote the JSON and Markdown results next to this report.</p>
          <div className="opt">
            <Link to="/view/print" onClick={close}>Print or save as PDF <small>all tests</small></Link>
            <Link to="/view/excel" onClick={close}>Table for Excel <small>copy and paste</small></Link>
            <Link to="/view/markdown" onClick={close}>Markdown <small>for a wiki or ticket</small></Link>
            <button type="button" onClick={() => { close(); copyText(failuresCsv(model), "Failures copied as CSV") }}>Copy failures as CSV <small>{model.failing.length} rows</small></button>
            <Link to="/config" onClick={close}>Maester config <small>edit and download</small></Link>
          </div>
        </Popover>
      )}
      <Toaster />
    </div>
  )
}
