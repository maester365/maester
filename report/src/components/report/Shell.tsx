// The frame of every page: top bar (tenant, search, Ask AI, export, theme), the sidebar built from the views,
// the main column, the test sheet and the toast.

import { useEffect, useMemo, useRef, useState, type ReactNode } from "react"
import { useTheme } from "@/components/ThemeProvider"
import { Link, useLocation, useNavigate } from "@/lib/router"
import { getAttachmentPath } from "@/lib/reportAttachments"
import { useReport } from "./ReportContext"
import { TestSheet } from "./TestDetail"
import { buildViews, type ViewDef } from "./views"
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
import { Flame, Icon, Pill, ProductMark, Toaster, copyText, formatDate, tenantLogo } from "./ui"
import { tenantInitials, tenantName } from "@/lib/tenants"

// The tenants of a merged result, under All tenants. A long list shows the first few and leaves the rest to the
// tenants page and the switcher.
const SIDEBAR_TENANTS = 8

function TenantNav({ onNavigate }: { onNavigate: () => void }) {
  const { models, tenantIndex, selectTenant } = useReport()
  const { pathname } = useLocation()
  return (
    <>
      {models.slice(0, SIDEBAR_TENANTS).map((m, i) => {
        const name = tenantName(m, i)
        const on = i === tenantIndex && pathname !== "/tenants"
        return (
          <a key={i} href="#/" className={`mt-nav${on ? " on" : ""}`} aria-current={on ? "page" : undefined}
            onClick={(e) => { e.preventDefault(); onNavigate(); selectTenant(i, "/") }}>
            <span className="mt-tav" aria-hidden="true">{tenantInitials(name)}</span><span className="lbl">{name}</span>
            <span className="ct bad">{m.all.Failed}</span>
          </a>
        )
      })}
      {models.length > SIDEBAR_TENANTS && <Link to="/tenants" className="mt-nav" onClick={onNavigate}><span className="lbl mt-muted">{models.length - SIDEBAR_TENANTS} more tenants</span></Link>}
    </>
  )
}

// Groups the reader folded, remembered in this browser only.
function useFolded() {
  const [folded, setFolded] = useState<string[]>(() => { try { return JSON.parse(localStorage.getItem("mt-nav-folded") || "[]") } catch { return [] } })
  const toggle = (g: string) => setFolded((f) => {
    const next = f.includes(g) ? f.filter((x) => x !== g) : [...f, g]
    try { localStorage.setItem("mt-nav-folded", JSON.stringify(next)) } catch { /* storage refused */ }
    return next
  })
  return [folded, toggle] as const
}

function Sidebar({ views, open, onNavigate }: { views: ViewDef[]; open: boolean; onNavigate: () => void }) {
  const { pathname } = useLocation()
  const { model, multi, tenantIndex } = useReport()
  const [folded, toggle] = useFolded()
  const groups = [...new Set(views.map((v) => v.group))]
  const isOn = (v: ViewDef) => (v.path === "/" ? pathname === "/" : pathname === v.path || pathname.startsWith(v.path + "/"))
  return (
    <nav className={`mt-side${open ? " open" : ""}`} aria-label="Report views">
      {groups.map((g) => {
        const list = views.filter((v) => v.group === g)
        // Only the longer lists fold; the selected view stays in sight in a folded group.
        const foldable = g === "Products" || g === "Frameworks" || g === "Packs" || g === "Reports"
        const shut = foldable && folded.includes(g)
        const shown = shut ? list.filter(isOn) : list
        const failed = list.reduce((n, v) => n + (v.bad && v.count ? v.count : 0), 0)
        // With several tenants, the selected tenant's views sit under its name.
        const title = multi && g === "Summary" ? tenantName(model, tenantIndex) : g
        return (
          <div key={g} className="mt-navgroup">
            {foldable ? (
              <button type="button" className="mt-navhead" aria-expanded={!shut} onClick={() => toggle(g)}>
                <span>{title}</span>{shut && failed > 0 && <span className="ct bad">{failed}</span>}<Icon name="chevron" className={`mt-ai mt-fold${shut ? " shut" : ""}`} />
              </button>
            ) : <h4>{title}</h4>}
            {shown.map((v) => {
              const on = isOn(v)
              return (
                <Link key={v.path} to={v.path} className={`mt-nav${on ? " on" : ""}`} aria-current={on ? "page" : undefined} onClick={onNavigate}>
                  {v.product ? <ProductMark product={v.product} size="sm" /> : v.code ? <span className="mt-code">{v.code}</span> : v.icon ? <Icon name={v.icon} /> : null}
                  <span className="lbl">{v.title}</span>
                  {/* A list of failures with none shows a tick, so a zero does not read as an empty view. */}
                  {v.count !== undefined && (v.bad && !v.count ? <span className="ct ok" aria-label="No failures"><Icon name="check" /></span> : <span className={`ct${v.bad && v.count ? " bad" : ""}`}>{v.count}</span>)}
                </Link>
              )
            })}
            {g === "Tenants" && <TenantNav onNavigate={onNavigate} />}
            {g === "Packs" && !shut && <a className="add" href="https://maester.dev/docs/packs" target="_blank" rel="noopener noreferrer">+ Add a pack to the next run</a>}
          </div>
        )
      })}
    </nav>
  )
}

function SearchPalette({ views, onClose }: { views: ViewDef[]; onClose: () => void }) {
  const { model, openTest } = useReport()
  const navigate = useNavigate()
  const [q, setQ] = useState("")
  const [sel, setSel] = useState(0)
  const input = useRef<HTMLInputElement>(null)
  useEffect(() => { input.current?.focus() }, [])
  const items = useMemo(() => {
    const query = q.toLowerCase().trim()
    const v = views.filter((x) => !query || x.title.toLowerCase().includes(query)).slice(0, query ? 5 : 8).map((x) => ({ kind: "view" as const, key: x.path, title: x.title, sub: x.group, result: "" }))
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

  const views = useMemo(() => buildViews(model, {
    affectedObjects: Array.isArray(r.AffectedObjects) && r.AffectedObjects.length > 0,
    attachments: model.attachments.map((a) => ({ title: a.Name, path: getAttachmentPath(a) })),
    tenants: models.length,
  }), [model, models, r])

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
  useEffect(() => { document.getElementById("report-main")?.scrollTo(0, 0); window.scrollTo(0, 0) }, [pathname])

  return (
    <div className="mt-app">
      <header className="mt-top">
        <button type="button" className="mt-btn icon mt-menu-btn" onClick={() => setNavOpen((o) => !o)} aria-label="Open navigation" aria-expanded={navOpen}><Icon name="menu" /></button>
        <Link to="/" className="mt-brand" aria-label="Maester report home"><Flame />Maester <small>Report</small></Link>
        <div className="mt-tenant">
          {multi ? (
            <button type="button" className="mt-btn mt-tenant-btn" onClick={() => setOverlay("tenant")} aria-haspopup="dialog">
              {onTenants ? <><Icon name="tenant" /><b>All tenants</b><span className="mt-badge">{models.length}</span></> : <><span className="mt-tav" aria-hidden="true">{tenantInitials(tenantName(model, tenantIndex))}</span><b>{tenantName(model, tenantIndex)}</b></>}
              <Icon name="chevron" />
            </button>
          ) : <b>{r.TenantName || r.TenantId || "Tenant"}</b>}
          {r.ExecutedAt && !onTenants && <span>{formatDate(r.ExecutedAt)}</span>}
        </div>
        <div className="mt-grow" />
        <button type="button" className="mt-btn mt-search" onClick={() => setOverlay("search")}><Icon name="search" /><span>Search tests, controls, techniques</span><kbd>⌘K</kbd></button>
        <button type="button" className="mt-btn mt-hide-sm" onClick={() => setOverlay("ai")}><Icon name="sparkle" />Ask AI</button>
        <button type="button" className="mt-btn mt-hide-sm" onClick={() => setOverlay("export")}>Export</button>
        {!onTenants && tenantLogo(r) && <img className="mt-logo mt-hide-sm" src={tenantLogo(r)} alt={String(r.TenantName || "Organisation")} />}
        <button type="button" className="mt-btn icon" onClick={() => setTheme(resolvedTheme === "dark" ? "light" : "dark")} aria-label="Switch between light and dark"><Icon name="moon" /></button>
      </header>
      <div className="mt-shell">
        <Sidebar views={views} open={navOpen} onNavigate={() => setNavOpen(false)} />
        <main id="report-main" className={`mt-main${flush ? " flush" : ""}`}>{children}</main>
      </div>
      <TestSheet />
      {overlay === "search" && <SearchPalette views={views} onClose={close} />}
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
