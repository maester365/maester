// The left menu (nav.ts builds what it lists). On the overview it is the home menu: the pages that cover the whole
// run and one row per hub. In a hub, the home menu folds into an icon rail and the hub's own menu, a tree of any
// depth, sits beside it. The reader can collapse the menu to the rail (a hub picked on the rail then opens over
// the page until a page is picked) and drag its edge to widen it; both are kept in this browser only. On a phone
// the menu is a drawer that drills into a hub, with no rail.

import { createContext, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react"
import { Link, useLocation, useNavigate } from "@/lib/router"
import { tenantInitials, tenantName } from "@/lib/tenants"
import type { Plan } from "@/lib/zeroTrust"
import { useReport } from "./ReportContext"
import { Icon, ProductMark } from "./ui"
import { walkItems, type Hub, type Located, type NavItem, type NavModel } from "./nav"

export interface NavState { nav: NavModel; here: Located; plans: Map<string, Plan> }
export const NavContext = createContext<NavState | null>(null)
export function useNav() {
  const v = useContext(NavContext)
  if (!v) throw new Error("useNav must be used inside the Shell")
  return v
}

const MIN_W = 200, MAX_W = 380
// A hub menu with more rows than this gets a box to filter it.
const FILTER_FROM = 12
// The tenants of a merged result, under All tenants. A long list shows the first few and leaves the rest to the
// tenants page and the switcher.
const SIDEBAR_TENANTS = 8

interface Prefs { collapsed: boolean; width: number | null }
function usePrefs() {
  const [prefs, setPrefs] = useState<Prefs>(() => {
    try { const s = JSON.parse(localStorage.getItem("mt-nav") || "{}"); return { collapsed: !!s.collapsed, width: typeof s.width === "number" ? s.width : null } } catch { return { collapsed: false, width: null } }
  })
  const update = (next: Partial<Prefs>) => setPrefs((p) => ({ ...p, ...next }))
  useEffect(() => { try { localStorage.setItem("mt-nav", JSON.stringify(prefs)) } catch { /* storage refused */ } }, [prefs])
  return [prefs, update] as const
}

function useNarrow() {
  const query = "(max-width: 900px)"
  const [narrow, setNarrow] = useState(() => typeof matchMedia === "function" && matchMedia(query).matches)
  useEffect(() => {
    if (typeof matchMedia !== "function") return
    const m = matchMedia(query)
    const on = () => setNarrow(m.matches)
    m.addEventListener("change", on)
    return () => m.removeEventListener("change", on)
  }, [])
  return narrow
}

function Mark({ it }: { it: Pick<NavItem, "product" | "code" | "icon"> }) {
  return it.product ? <ProductMark product={it.product} size="sm" /> : it.code ? <span className="mt-code">{it.code}</span> : it.icon ? <Icon name={it.icon} /> : null
}

// A list of failures with none shows a tick, so a zero does not read as an empty view.
function Count({ it }: { it: NavItem }) {
  if (it.prog) {
    const [d, t] = it.prog
    return t ? <span className="mt-nprog" title={`${d} of ${t} checked tasks done`}><b aria-hidden="true"><i style={{ width: `${(d / t) * 100}%` }} /></b><span>{d}/{t}</span></span> : null
  }
  if (it.count === undefined) return null
  return it.bad && !it.count ? <span className="ct ok" aria-label="No failures"><Icon name="check" /></span> : <span className={`ct${it.bad && it.count ? " bad" : ""}`}>{it.count}</span>
}

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

/** Rows whose title has the words, with the rows above them. */
function filterTree(items: NavItem[], q: string): NavItem[] {
  const words = q.toLowerCase().split(/\s+/).filter(Boolean)
  const hit = (t: string) => words.every((w) => t.toLowerCase().includes(w))
  return items.flatMap((it) => {
    const kids = it.items ? filterTree(it.items, q) : []
    if (hit(it.title) && !it.section) return [{ ...it, items: it.items }]
    return kids.length ? [{ ...it, items: kids }] : []
  })
}

export function Sidebar({ drawer, onNavigate, collapseRef }: {
  drawer: boolean
  /** Closes the phone drawer once a page is picked. */
  onNavigate: () => void
  /** The top bar's menu button collapses and expands the menu through this. */
  collapseRef: { current: (() => void) | null }
}) {
  const { nav, here } = useNav()
  const { model, multi, tenantIndex } = useReport()
  const { pathname } = useLocation()
  const navigate = useNavigate()
  const narrow = useNarrow()
  const [prefs, setPrefs] = usePrefs()
  const [atHome, setAtHome] = useState(false)
  const [peek, setPeek] = useState<string | null>(null)
  const [open, setOpen] = useState<Set<string>>(() => new Set())
  const [q, setQ] = useState("")
  const [slide, setSlide] = useState("")
  const [drag, setDrag] = useState(false)
  const navRef = useRef<HTMLElement>(null)

  const collapsed = prefs.collapsed && !narrow
  const shownHub: Hub | null = (peek && nav.hubs.find((h) => h.key === peek)) || (atHome ? null : here.hub)
  const railShown = !narrow && (collapsed || !!shownHub)
  const menuShown = narrow || !collapsed || !!peek

  // A new page shows its own hub's menu, with the rows above it open.
  useEffect(() => {
    setAtHome(false); setPeek(null)
    if (here.trail.length) setOpen((o) => { const n = new Set(o); for (const t of here.trail) n.add(t.key); return n })
  }, [pathname, here.item?.key]) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { setQ("") }, [shownHub?.key])

  const toggleCollapsed = () => { setPeek(null); setPrefs({ collapsed: !prefs.collapsed }) }
  collapseRef.current = toggleCollapsed

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const t = e.target as HTMLElement | null
      const typing = !!t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable)
      if (e.key === "Escape" && peek) { setPeek(null); e.preventDefault() }
      else if (e.key === "[" && !typing && !e.metaKey && !e.ctrlKey && !e.altKey && !narrow) { setPeek(null); setPrefs({ collapsed: !prefs.collapsed }) }
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  })
  // A hub opened over the page closes when the reader clicks the page.
  useEffect(() => {
    if (!peek) return
    const onDown = (e: MouseEvent) => { if (!navRef.current?.contains(e.target as Node)) setPeek(null) }
    document.addEventListener("mousedown", onDown)
    return () => document.removeEventListener("mousedown", onDown)
  }, [peek])

  const pickPage = () => { setPeek(null); onNavigate() }
  const openHub = (key: string) => {
    const hub = nav.hubs.find((h) => h.key === key)
    if (!hub) return
    if (collapsed) { setPeek((p) => (p === key ? null : key)); return }
    setSlide("in")
    // On a phone the drawer stays open to show the hub's menu.
    if (here.hub?.key === key) setAtHome(false)
    else navigate(hub.path)
  }
  const goHome = () => { setSlide("out"); setPeek(null); setAtHome(true) }
  const toggle = (key: string) => setOpen((o) => { const n = new Set(o); if (n.has(key)) n.delete(key); else n.add(key); return n })

  const startDrag = (e: React.PointerEvent) => {
    const menu = (e.currentTarget as HTMLElement).parentElement
    if (!menu) return
    e.preventDefault()
    const left = menu.getBoundingClientRect().left
    setDrag(true)
    let width = prefs.width
    const move = (ev: PointerEvent) => {
      width = Math.round(Math.min(MAX_W, Math.max(MIN_W, ev.clientX - left)))
      menu.style.setProperty("--mt-mw", `${width}px`)
    }
    const up = () => { window.removeEventListener("pointermove", move); window.removeEventListener("pointerup", up); setDrag(false); setPrefs({ width }) }
    window.addEventListener("pointermove", move)
    window.addEventListener("pointerup", up)
  }

  const isOn = (it: NavItem) => !!it.path && here.item?.path === it.path
  const row = (it: NavItem, extra?: ReactNode, depth = 0) => {
    const body = <><Mark it={it} /><span className="lbl">{it.title}</span><Count it={it} />{extra}</>
    const cls = `mt-nav${isOn(it) ? " on" : ""}${depth ? " child" : ""}`
    if (it.hub) return <button key={it.key} type="button" className={`${cls}${shownHub?.key === it.hub || here.hub?.key === it.hub ? " in" : ""}`} onClick={() => openHub(it.hub!)}>{body}<Icon name="next" className="mt-ai mt-nchev" /></button>
    if (!it.path) return <button key={it.key} type="button" className={cls} aria-expanded={open.has(it.key)} onClick={() => toggle(it.key)}>{body}</button>
    return <Link key={it.key} to={it.path} className={cls} aria-current={isOn(it) ? "page" : undefined} onClick={pickPage}>{body}</Link>
  }

  const tree = (items: NavItem[], depth: number, filtering: boolean): ReactNode => {
    const sibKids = items.some((it) => !it.section && it.items?.length)
    return items.map((it) => {
      if (it.section) return <div key={it.key} className="mt-ngroup"><h4 style={{ marginLeft: depth * 14 + 10 }}>{it.title}</h4>{tree(it.items || [], depth, filtering)}</div>
      const kids = !!it.items?.length
      const expanded = filtering || open.has(it.key)
      return (
        <div key={it.key}>
          <div className="mt-tree" style={depth ? { paddingLeft: depth * 14 } : undefined}>
            {kids ? <button type="button" className="mt-tw" aria-expanded={expanded} aria-label={`${expanded ? "Collapse" : "Expand"} ${it.title}`} onClick={() => toggle(it.key)}><Icon name="next" /></button>
              : sibKids || depth ? <span className="mt-twgap" aria-hidden="true" /> : null}
            {row(it, undefined, depth)}
          </div>
          {kids && expanded && tree(it.items!, depth + 1, filtering)}
        </div>
      )
    })
  }

  const rowCount = (items: NavItem[]): number => items.reduce((n, it) => n + (it.section ? 0 : 1) + (it.items ? rowCount(it.items) : 0), 0)
  const homeTitle = multi ? tenantName(model, tenantIndex) : "Report"

  const tools = (start: ReactNode) => (
    <div className="mt-mtools">
      {start}
      {!narrow && (peek
        ? <button type="button" className="mt-mini pin" onClick={() => { setPeek(null); setPrefs({ collapsed: false }) }} title="Keep the menu open  [">Keep open</button>
        : <button type="button" className="mt-mini" onClick={toggleCollapsed} aria-label="Collapse the menu" title="Collapse the menu  ["><Icon name="panel" /></button>)}
    </div>
  )

  const homeMenu = (
    <>
      {tools(<span className="mt-eyebrow">{homeTitle}</span>)}
      {nav.home.map((g) => (g.items.length || g.addPack ? (
        <div key={g.key} className="mt-ngroup">
          {g.title && g.key !== "summary" ? <h4>{g.title}</h4> : g.key === "reports" || g.key === "hubs" ? <hr className="mt-ndiv" /> : null}
          {g.items.map((it) => row(it))}
          {g.tenants && <TenantNav onNavigate={onNavigate} />}
          {g.addPack && <a className="add" href="https://packs.maester.cloud/" target="_blank" rel="noopener noreferrer">+ Add a pack to the next run</a>}
        </div>
      ) : null))}
    </>
  )

  const hubMenu = (hub: Hub) => {
    const filtering = !!q.trim()
    const items = filtering ? filterTree(hub.items, q.trim()) : hub.items
    return (
      <>
        {tools(<button type="button" className="mt-back" onClick={goHome}><Icon name="prev" />{homeTitle}</button>)}
        <div className="mt-hubhead">
          <span className={`big${hub.code ? " code" : ""}`}>{hub.code || (hub.icon ? <Icon name={hub.icon} /> : null)}</span>
          <span><b>{hub.title}</b><span>{hub.sub}</span></span>
        </div>
        {rowCount(hub.items) > FILTER_FROM && (
          <label className="mt-nfilter"><Icon name="search" /><input value={q} placeholder="Filter this menu" aria-label={`Filter the ${hub.title} menu`} onInput={(e) => setQ((e.target as HTMLInputElement).value)}
            onKeyDown={(e) => { if (e.key === "Escape" && q) { e.stopPropagation(); setQ("") } }} /></label>
        )}
        {items.length ? tree(items, 0, filtering) : <p className="mt-note mt-nempty">Nothing in this menu matches.</p>}
      </>
    )
  }

  // The rail: one button per home row, separated as the home menu is.
  const rail = (
    <div className="mt-rail" aria-label="Report sections">
      {collapsed && <><button type="button" onClick={toggleCollapsed} aria-label="Expand the menu" title="Expand the menu  ["><Icon name="panel" /></button><hr /></>}
      {nav.home.map((g, gi) => (
        <div key={g.key} className="mt-railgroup">
          {gi > 0 && g.items.length ? <hr /> : null}
          {g.items.map((it) => {
            const on = it.hub ? (shownHub?.key === it.hub || (!shownHub && here.hub?.key === it.hub)) : !shownHub && isOn(it)
            const dot = it.bad && !!it.count
            const inner = <>{it.code ? <span className="mt-code">{it.code}</span> : it.product ? <ProductMark product={it.product} size="sm" /> : it.icon ? <Icon name={it.icon} /> : <span className="mt-code">{it.title.slice(0, 2)}</span>}{dot && <i className="dot" />}</>
            return it.hub
              ? <button key={it.key} type="button" className={on ? "on" : ""} aria-label={it.title} title={it.title} aria-expanded={collapsed ? peek === it.hub : undefined} onClick={() => openHub(it.hub!)}>{inner}</button>
              : <Link key={it.key} to={it.path!} className={on ? "on" : ""} aria-label={it.title} title={it.title} aria-current={isOn(it) ? "page" : undefined} onClick={pickPage}>{inner}</Link>
          })}
        </div>
      ))}
    </div>
  )

  const width = prefs.width ? { ["--mt-mw" as string]: `${prefs.width}px` } : undefined
  const cls = ["mt-side", drawer && "open", shownHub && "inhub", collapsed && "collapsed", peek && "peek"].filter(Boolean).join(" ")
  return (
    <nav ref={navRef} className={cls} aria-label="Report menu">
      {railShown && rail}
      {menuShown && (
        <div className="mt-menuwrap" style={width}>
          <div key={shownHub?.key || "home"} className={`mt-menu${slide === "in" ? " slide" : slide === "out" ? " slideback" : ""}`} onAnimationEnd={() => setSlide("")}>
            {shownHub ? hubMenu(shownHub) : homeMenu}
          </div>
          {!narrow && <div className={`mt-grip${drag ? " drag" : ""}`} role="separator" aria-orientation="vertical" aria-label="Drag to resize the menu; double-click to reset it" onPointerDown={startDrag} onDoubleClick={() => setPrefs({ width: null })} />}
        </div>
      )}
    </nav>
  )
}

/** The path to the page: Report, the hub and the rows above the page, each a link. Only pages in a hub have one. */
export function Crumbs({ flush }: { flush?: boolean }) {
  const { here } = useNav()
  const wide = here.item?.page?.view === "plan"
  const { model, multi, tenantIndex } = useReport()
  if (!here.hub || !here.item) return null
  const parts = [{ title: multi ? tenantName(model, tenantIndex) : "Report", path: "/" }, { title: here.hub.title, path: here.hub.path }, ...here.trail.map((t) => ({ title: t.title, path: t.path }))]
  return (
    <nav className={`mt-crumbs${wide ? " wide" : ""}${flush ? " flush" : ""}`} aria-label="Breadcrumb">
      {parts.map((p, i) => <span key={i}>{p.path ? <Link to={p.path}>{p.title}</Link> : p.title}<span aria-hidden="true">›</span></span>)}
      <b aria-current="page">{here.item.title}</b>
    </nav>
  )
}

/** Every page in the menu, for search. */
export function useNavPages() {
  const { nav } = useNav()
  return useMemo(() => {
    const out: { path: string; title: string; sub: string }[] = []
    const seen = new Set<string>()
    const add = (path: string, title: string, sub: string) => { if (!seen.has(path)) { seen.add(path); out.push({ path, title, sub }) } }
    for (const g of nav.home) for (const { item } of walkItems(g.items)) add(item.path!, item.title, "Report")
    for (const h of nav.hubs) for (const { item, trail } of walkItems(h.items)) add(item.path!, item.title, [h.title, ...trail.map((t) => t.title)].join(" › "))
    return out
  }, [nav])
}
