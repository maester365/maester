// The Zero Trust plan: Microsoft's Zero Trust Workshop for one pillar, with what this run found for each task.
// A summary and the tasks to do next, then one functional area at a time as a board (swimlanes by phase), or every
// task as a table grouped by functional area and swimlane. A task opens in a panel on the right, over the
// blurred board or table. The plan comes from the Zero Trust Assessment pack (see lib/zeroTrust.ts).

import { useCallback, useEffect, useRef, useState, type ReactNode } from "react"
import { Markdown } from "@/components/Markdown"
import { peekKeepScroll, useLocation, useNavigate } from "@/lib/router"
import {
  LEVEL, PHASES, PHASE_RANK, STATUSES, STATUS_LABEL, STATUS_RANK, blockersOf, cleanDoc, dependentsOf, orderedChecks,
  priorityRank, usePlan, type Check, type Pillar, type Plan, type Task, type TaskStatus,
} from "@/lib/zeroTrust"
import { slug } from "@/lib/packNav"
import { useReport } from "@/components/report/ReportContext"
import { Footer } from "@/components/report/lists"
import { Icon, Pill, plural } from "@/components/report/ui"
import { TaskIcon, ZeroTrustBoard } from "@/components/report/ZeroTrustBoard"

type View = "board" | "table"

type Filters = { status: Set<string>; phase: Set<string>; priority: Set<string>; effort: Set<string> }
const FILTERS: { key: keyof Filters; label: string; options: [string, string][]; get: (t: Task) => string }[] = [
  { key: "status", label: "Status", options: STATUSES.map((s) => [s, STATUS_LABEL[s]]), get: (t) => t.st },
  { key: "phase", label: "Phase", options: PHASES.map((p) => [p, p]), get: (t) => t.phase },
  { key: "priority", label: "Priority", options: [["P0", "P0"], ["P1", "P1"], ["P2", "P2"], ["P3", "P3"], ["none", "No priority"]], get: (t) => t.priority || "none" },
  { key: "effort", label: "Effort", options: [["Low", "Low"], ["Medium", "Medium"], ["High", "High"], ["none", "Not set"]], get: (t) => t.effort || "none" },
]
const emptyFilters = (): Filters => ({ status: new Set(), phase: new Set(), priority: new Set(), effort: new Set() })

const COLUMNS: { key: string; label: string; sm?: boolean; value: (t: Task) => string | number }[] = [
  { key: "task", label: "Task", value: (t) => t.name.toLowerCase() },
  { key: "status", label: "Status", value: (t) => STATUS_RANK[t.st] },
  { key: "phase", label: "Phase", sm: true, value: (t) => PHASE_RANK[t.phase] },
  { key: "priority", label: "Priority", sm: true, value: (t) => priorityRank(t.priority ?? undefined) },
  { key: "checks", label: "Checks", value: (t) => (t.ran.length ? t.passes.length / t.ran.length : t.checks.length ? -0.5 : -1) },
  { key: "effort", label: "Effort", sm: true, value: (t) => LEVEL[t.effort || ""] || 9 },
  { key: "impact", label: "User impact", sm: true, value: (t) => LEVEL[t.userImpact || ""] || 9 },
  { key: "licence", label: "Licence", sm: true, value: (t) => t.license || "~" },
]

const SOURCE: Record<string, string> = { microsoft: "Zero Trust mapping", maester: "Maester mapping" }
const isOpenTask = (t: Task) => t.st === "notdone" || t.st === "partial"

function StatusBadge({ st }: { st: TaskStatus }) {
  return <span className={`mt-zt-st s-${st}`}><i className={`mt-zt-dot s-${st}`} />{STATUS_LABEL[st]}</span>
}

function Rollup({ tasks }: { tasks: Task[] }) {
  const n = tasks.length || 1
  const c = (s: TaskStatus) => tasks.filter((t) => t.st === s).length
  return (
    <span className="mt-zt-roll" role="img" aria-label={`${c("done")} done, ${c("partial")} partly done, ${c("notdone")} not done, ${c("unknown") + c("manual")} to review`}>
      {(["done", "partial", "notdone", "unknown"] as TaskStatus[]).map((s) => c(s) ? <i key={s} className={`s-${s}`} style={{ width: `${(c(s) / n) * 100}%` }} /> : null)}
    </span>
  )
}

function rollText(tasks: Task[]) {
  const ck = tasks.filter((t) => t.st !== "manual")
  const fix = tasks.filter(isOpenTask).length
  const review = tasks.filter((t) => t.st === "manual" || t.st === "unknown").length
  return `${ck.length ? `${ck.filter((t) => t.st === "done").length} of ${ck.length} done` : "Nothing Maester checks"}${fix ? ` · ${fix} to fix` : ""}${review ? ` · ${review} to review` : ""}`
}

function CheckBar({ task }: { task: Task }) {
  if (!task.checks.length) return <span className="mt-muted">No checks</span>
  const p = task.passes.length, f = task.fails.length, other = task.checks.length - p - f
  return (
    <span className="mt-zt-checks" title={`${p} passed, ${f} failed, ${other} did not run`}>
      <span className="b" aria-hidden="true">{p ? <i className="p" style={{ flex: p }} /> : null}{f ? <i className="f" style={{ flex: f }} /> : null}{other ? <i className="o" style={{ flex: other }} /> : null}</span>
      <span className="mt-num">{p}/{task.checks.length}</span>
    </span>
  )
}

const Level = ({ value }: { value: string | null }) => (value ? <span className="mt-zt-level"><b aria-hidden="true">{[1, 2, 3].map((i) => <i key={i} className={i <= (LEVEL[value] || 0) ? "on" : ""} />)}</b>{value}</span> : <span className="mt-muted">–</span>)
const Priority = ({ value }: { value: string | null }) => (value ? <span className={`mt-zt-prio ${value.toLowerCase()}`}>{value}</span> : <span className="mt-muted">–</span>)

function FilterMenu({ def, value, onChange }: { def: (typeof FILTERS)[number]; value: Set<string>; onChange: (next: Set<string>) => void }) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    if (!open) return
    const onDoc = (e: MouseEvent) => { if (!ref.current?.contains(e.target as Node)) setOpen(false) }
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") { e.stopPropagation(); setOpen(false) } }
    document.addEventListener("mousedown", onDoc)
    window.addEventListener("keydown", onKey, true)
    return () => { document.removeEventListener("mousedown", onDoc); window.removeEventListener("keydown", onKey, true) }
  }, [open])
  const names = def.options.filter(([v]) => value.has(v)).map(([, l]) => l)
  return (
    <div className="mt-zt-fm" ref={ref}>
      <button type="button" className={`mt-btn${value.size ? " on" : ""}`} aria-expanded={open} onClick={() => setOpen((o) => !o)}>
        {def.label}{names.length ? <b>: {names.length > 2 ? `${names.length} selected` : names.join(", ")}</b> : null}<Icon name="chevron" />
      </button>
      {open && (
        <div className="mt-zt-fmenu" role="group" aria-label={def.label}>
          {def.options.map(([v, l]) => (
            <label key={v}><input type="checkbox" checked={value.has(v)} onChange={() => { const next = new Set(value); if (next.has(v)) next.delete(v); else next.add(v); onChange(next) }} />
              {def.key === "status" ? <i className={`mt-zt-dot s-${v}`} /> : null}{l}</label>
          ))}
          {value.size ? <button type="button" className="mt-link" onClick={() => onChange(new Set())}>Clear</button> : null}
        </div>
      )}
    </div>
  )
}

function Tiles({ pillar }: { pillar: Pillar }) {
  const ts = pillar.tasks
  const checkable = ts.filter((t) => t.st !== "manual")
  const done = checkable.filter((t) => t.st === "done")
  const fix = ts.filter(isOpenTask)
  const review = ts.filter((t) => t.st === "manual" || t.st === "unknown")
  const ran = ts.flatMap((t) => t.ran)
  const pass = ts.flatMap((t) => t.passes)
  const byPhase = (list: Task[], of?: Task[]) => PHASES.map((p) => ({ p, v: list.filter((t) => t.phase === p).length, max: of ? of.filter((t) => t.phase === p).length : 0 }))
  const spark = (vals: { p: string; v: number; max: number }[], cls: string) => {
    const top = Math.max(1, ...vals.map((x) => x.max || x.v))
    return <span className="mt-zt-spark" aria-hidden="true">{vals.map((x) => <span key={x.p} title={`${x.p}: ${x.max ? `${x.v} of ${x.max}` : x.v}`}><b><i className={cls} style={{ height: `${((x.v / (x.max || top)) || 0) * 100}%` }} /></b>{x.p[0]}</span>)}</span>
  }
  const tile = (label: ReactNode, value: ReactNode, sub: string, sp: ReactNode) => <div className="mt-zt-tile"><div className="k">{label}</div><div className="v">{value}</div>{sp}<div className="s">{sub}</div></div>
  return (
    <div className="mt-zt-tiles">
      {tile(<><i className="mt-zt-dot s-done" />Tasks done</>, <>{done.length}<small> of {checkable.length}</small></>, "Tasks Maester checks, with every check passing", spark(byPhase(done, checkable), "s-done"))}
      {tile(<><i className="mt-zt-dot s-notdone" />To fix</>, fix.length, `${ts.filter((t) => t.st === "notdone").length} not done · ${ts.filter((t) => t.st === "partial").length} partly done`, spark(byPhase(fix), "s-notdone"))}
      {tile(<><i className="mt-zt-dot s-info" />Checks passing</>, ran.length ? `${Math.round((pass.length / ran.length) * 100)}%` : "–", `${pass.length} of ${ran.length} checks that ran`, spark(PHASES.map((p) => ({ p, v: ts.filter((t) => t.phase === p).flatMap((t) => t.passes).length, max: ts.filter((t) => t.phase === p).flatMap((t) => t.ran).length })), "s-info"))}
      {tile(<><i className="mt-zt-dot s-manual" />Review yourself</>, review.length, `${ts.filter((t) => t.st === "manual").length} with no check · ${ts.filter((t) => t.st === "unknown").length} couldn't check`, spark(byPhase(review), "s-manual"))}
    </div>
  )
}

function TaskPanel({ plan, task, view, onGo, onSwap, onClose }: { plan: Plan; task: Task; view: View; onGo: (id: string) => void; onSwap: () => void; onClose: () => void }) {
  const { openTest, openId } = useReport()
  const closeRef = useRef<HTMLButtonElement>(null)
  const panel = useRef<HTMLElement>(null)
  const pillar = plan.pillars.find((p) => p.id === task.pillarId)
  const area = pillar?.areas.find((a) => a.id === task.areaId)
  const deps = task.dependencies.map((d) => plan.byId.get(d)).filter((d): d is Task => !!d)
  const after = dependentsOf(plan, task)
  const checks = orderedChecks(task)
  const doc = cleanDoc(task.doc)
  useEffect(() => { panel.current?.scrollTo(0, 0) }, [task.id])
  useEffect(() => { closeRef.current?.focus({ preventScroll: true }) }, [])
  useEffect(() => {
    // Escape closes the test sheet first when one is open over the panel.
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape" && !openId && !e.defaultPrevented) onClose() }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [onClose, openId])
  const taskLink = (d: Task, extra?: ReactNode) => (
    <button key={d.id} type="button" className="mt-zt-tlink" onClick={() => onGo(d.id)}>
      <i className={`mt-zt-dot s-${d.st}`} /><span className="nm">{d.name}</span>
      <span className="mt-muted">{extra ?? STATUS_LABEL[d.st]}{d.areaId !== task.areaId ? ` · ${pillar?.areas.find((a) => a.id === d.areaId)?.name || ""}` : ""}</span>
    </button>
  )
  const checkRow = (c: Check) => {
    const via = c.Source === "same-check" ? `Same check as ${c.Via}` : SOURCE[c.Source || ""] || ""
    const body = <>
      {c.row ? <Pill result={c.result} /> : <span className="mt-badge">Not in this run</span>}
      <span><span className="mt-mono id">{c.Id}</span> {c.title !== c.Id ? c.title : ""}<span className="src">{via}</span></span>
    </>
    return c.row
      ? <button key={c.Id} type="button" className="mt-zt-check" onClick={() => openTest(c.Id, checks.filter((x) => x.row).map((x) => x.Id))}>{body}</button>
      : <div key={c.Id} className="mt-zt-check">{body}</div>
  }
  return (
    <>
    <div className="mt-scrim zt" onClick={onClose} />
    <aside ref={panel} className="mt-zt-fly" role="dialog" aria-labelledby="mt-zt-fly-title">
      <button ref={closeRef} type="button" className="mt-btn icon mt-zt-x" onClick={onClose} aria-label="Close" title="Close (Esc)"><Icon name="close" /></button>
      <div className="mt-zt-flyhead">
        <div className="mt-eyebrow">{area?.name}{task.swimlane ? ` › ${task.swimlane}` : ""}</div>
        <div className="t"><TaskIcon plan={plan} task={task} size="lg" /><h2 id="mt-zt-fly-title">{task.name}</h2></div>
        <div className="mt-zt-statusline"><StatusBadge st={task.st} />{task.checks.length ? <span className="mt-muted">{task.passes.length} of {task.ran.length || task.checks.length} checks pass</span> : <span className="mt-muted">No check measures this task. Review it yourself.</span>}</div>
        <div className="mt-zt-meta">
          <span className="mt-chip">{task.phase}</span>
          {task.priority && <span className="mt-chip">{task.priority}</span>}
          {task.effort && <span className="mt-chip">Effort {task.effort}</span>}
          {task.userImpact && <span className="mt-chip">User impact {task.userImpact}</span>}
          {task.license && <span className="mt-chip">{task.license}</span>}
          {task.cisa && <span className="mt-chip">CISA {task.cisa}</span>}
          {task.origin === "maester" && <span className="mt-chip ember">Added by Maester</span>}
        </div>
        <button type="button" className="mt-btn" onClick={onSwap}><Icon name={view === "table" ? "feature" : "framework"} />{view === "table" ? "Show in the swimlanes" : "Show in the table"}</button>
      </div>
      <div className="mt-zt-flybody">
        {task.note && <div className="mt-callout"><span>{task.note}</span></div>}
        {deps.length > 0 && <section><h3>Do first</h3><div className="mt-zt-tlist">{deps.map((d) => taskLink(d))}</div></section>}
        <section>
          <h3>Checks</h3>
          {checks.length ? <div className="mt-zt-checklist">{checks.map(checkRow)}</div> : <p className="mt-note">No Maester or Zero Trust Assessment check measures this task.</p>}
        </section>
        {after.length > 0 && <section><h3>Comes before</h3><div className="mt-zt-tlist">{after.map((d) => taskLink(d))}</div></section>}
        <section>
          <h3>Workshop guidance</h3>
          {doc ? <Markdown className="mt-md mt-zt-doc">{doc}</Markdown> : <p className="mt-note">The workshop has no guidance page for this task.</p>}
        </section>
      </div>
    </aside>
    </>
  )
}

/** The plan of one pillar. The link names the pillar, the functional area the board shows and, from the menu, one
 * swimlane; "#table" shows the table. Under the pack's menu the base is the plan's own link (/pack/zta/plan). */
export default function ZeroTrustPage({ name, base, pillarId = "", areaId = "", lane = "" }: { name?: string; base: string; pillarId?: string; areaId?: string; lane?: string }) {
  const { model } = useReport()
  const { pathname, hash } = useLocation()
  const navigate = useNavigate()
  const { attachment, plan, error } = usePlan(model, name)

  if (!attachment) return <div className="mt-wrap"><h1 className="mt-h1">Zero Trust plan</h1><p className="mt-lead">This run has no Zero Trust plan. Run the Zero Trust Assessment pack (<code>Invoke-Maester -Pack ZTA</code>) to add it.</p></div>
  if (error) return <div className="mt-wrap"><h1 className="mt-h1">Zero Trust plan</h1><div className="mt-callout warn"><span>{error}</span></div></div>
  if (!plan) return <div className="mt-wrap"><h1 className="mt-h1">Zero Trust plan</h1><p className="mt-note">Opening the plan…</p></div>
  const pillar = plan.pillars.find((p) => p.id === pillarId) || plan.pillars.find((p) => p.checksInRun) || plan.pillars[0]
  if (!pillar) return <div className="mt-wrap"><h1 className="mt-h1">Zero Trust plan</h1><p className="mt-lead">The plan has no pillars.</p></div>
  const view: View = hash === "#table" ? "table" : "board"
  const area = pillar.areas.find((a) => a.id === areaId)?.id || pillar.next[0]?.areaId || pillar.areas[0]?.id || ""
  return <PillarView key={pillar.id} plan={plan} pillar={pillar} view={view} area={area} lane={areaId === area ? lane : ""} focus={!!areaId}
    setView={(v) => navigate(`${pathname}${v === "table" ? "#table" : ""}`, { replace: true, keepScroll: true })}
    setArea={(id, v = view) => navigate(`${base}/${encodeURIComponent(pillar.id)}/${encodeURIComponent(id)}${v === "table" ? "#table" : ""}`, { keepScroll: true })} />
}

function PillarView({ plan, pillar, view, area, lane, focus, setView, setArea }: {
  plan: Plan; pillar: Pillar; view: View; area: string
  /** The link names an area: show the board rather than the top of the page. */
  focus: boolean
  /** One swimlane of the area, as its name in a link, when the menu opened one. */
  lane: string
  setView: (v: View) => void
  setArea: (id: string, view?: View) => void
}) {
  const [q, setQ] = useState("")
  const [filters, setFilters] = useState<Filters>(emptyFilters)
  const [checkedOnly, setCheckedOnly] = useState(false)
  const [sort, setSort] = useState<{ key: string | null; dir: 1 | -1 }>({ key: null, dir: 1 })
  const [collapsed, setCollapsed] = useState<Set<string>>(() => new Set())
  const [selected, setSelected] = useState<string | null>(null)
  const laneDef = lane ? pillar.areas.find((a) => a.id === area)?.lanes.find((l) => slug(l.name) === lane) : undefined
  const laneKey = laneDef?.key
  const boardRef = useRef<HTMLElement>(null)
  // An area or swimlane picked in the menu scrolls to the board, after the Shell's scroll to the top of a new page.
  // A move within the page (an area card, a task in another area) keeps the reader's place.
  useEffect(() => {
    if (!focus || peekKeepScroll()) return
    const id = requestAnimationFrame(() => boardRef.current?.scrollIntoView({ block: "start" }))
    return () => cancelAnimationFrame(id)
  }, [area, lane]) // eslint-disable-line react-hooks/exhaustive-deps

  const task = selected ? plan.byId.get(selected) || null : null
  const areaName = (id: string) => pillar.areas.find((a) => a.id === id)?.name || ""
  const match = useCallback((t: Task) => {
    if (checkedOnly && !t.checks.length) return false
    for (const f of FILTERS) { const s = filters[f.key]; if (s.size && !s.has(f.get(t))) return false }
    if (q) {
      const hay = [t.name, t.id, t.swimlane, areaName(t.areaId), ...t.checks.flatMap((c) => [c.Id, c.title])].join(" ").toLowerCase()
      if (!q.toLowerCase().split(/\s+/).every((w) => hay.includes(w))) return false
    }
    return true
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q, filters, checkedOnly, pillar])
  const anyFilter = !!q || checkedOnly || FILTERS.some((f) => filters[f.key].size)
  const clear = () => { setQ(""); setFilters(emptyFilters()); setCheckedOnly(false) }
  // Scrolls to the task's row or card once the view has drawn it (after a switch of view, a frame or two later).
  const reveal = (t: Task, in_: View, smooth = true) => {
    let tries = 0
    const go = () => {
      const el = document.getElementById(`mt-zt-${in_ === "table" ? "row" : "card"}-${t.id}`)
      if (el) el.scrollIntoView({ block: "center", behavior: smooth ? "smooth" : "auto" })
      else if (tries++ < 20) requestAnimationFrame(go)
    }
    requestAnimationFrame(go)
  }

  // Opening a task from anywhere: the board switches to its area, the table opens its rows; both bring it into view.
  const open = (id: string, from?: "list" | "link") => {
    const t = plan.byId.get(id)
    if (!t) return
    if (t.pillarId !== pillar.id) return
    setSelected(id)
    if (!match(t)) clear()
    if (view === "board") { if (t.areaId !== area || (lane && t.laneKey !== laneKey)) setArea(t.areaId) }
    else setCollapsed((c) => { const n = new Set(c); n.delete(`a:${t.areaId}`); n.delete(`l:${t.laneKey}`); return n })
    if (from) reveal(t, view)
  }
  const swap = () => {
    const next: View = view === "table" ? "board" : "table"
    if (task && next === "board" && task.areaId !== area) setArea(task.areaId, next)
    else setView(next)
    if (task) reveal(task, next, false)
  }
  const close = useCallback(() => setSelected(null), [])

  const sortTasks = (ts: Task[]) => {
    if (!sort.key) return ts
    const col = COLUMNS.find((c) => c.key === sort.key)!
    return [...ts].sort((a, b) => { const x = col.value(a), y = col.value(b); return (x < y ? -1 : x > y ? 1 : 0) * sort.dir || a.index - b.index })
  }
  const toggle = (k: string) => setCollapsed((c) => { const n = new Set(c); if (n.has(k)) n.delete(k); else n.add(k); return n })
  const shown = pillar.tasks.filter(match).length

  return (
    <div className="mt-wrap wide mt-zt">
      <div className="mt-head">
        <div className="mt-eyebrow">Zero Trust · {plan.source?.Name || "Microsoft Zero Trust Workshop"}</div>
        <h1 className="mt-h1">{pillar.name}</h1>
        <p className="mt-lead">The workshop's {pillar.name} plan with what this run found. Every task is listed, grouped by functional area and swimlane, in the workshop's three phases: First, Then and Next. A task is done when every check that measures it passed; tasks no check measures are yours to review.</p>
      </div>
      {!pillar.checksInRun && <div className="mt-callout"><span>None of the checks that measure the {pillar.name} tasks ran, so every task shows as one to review. Run the Zero Trust Assessment for this pillar, or Maester's own tests, to measure them.</span></div>}
      <Tiles pillar={pillar} />

      {pillar.next.length > 0 && (
        <section className="mt-sec">
          <div className="mt-sechead"><h2 className="mt-h2">Do these next</h2><span className="mt-note">You're in the {pillar.current} phase: {pillar.tasks.filter((t) => t.phase === pillar.current && t.st === "done").length} of {pillar.tasks.filter((t) => t.phase === pillar.current && t.st !== "manual").length} checked {pillar.current} tasks done.</span></div>
          <ol className="mt-zt-next">
            {pillar.next.map((t, i) => {
              const b = blockersOf(plan, t)
              return (
                <li key={t.id}><button type="button" aria-pressed={selected === t.id} onClick={() => open(t.id, "list")}>
                  <span className="n">{i + 1}</span>
                  <span className="nm">{t.name}</span>
                  <span className="why"><StatusBadge st={t.st} /><span className="mt-chip">{t.phase}</span>{t.priority && <Priority value={t.priority} />}<span>{t.fails.length} of {t.ran.length} checks fail</span></span>
                  <span className="mt-muted sub">{areaName(t.areaId)} › {t.swimlane}{b.length ? ` · after ${b.map((x) => x.name).join(", ")}` : ""}</span>
                </button></li>
              )
            })}
          </ol>
        </section>
      )}

      <section className="mt-sec mt-zt-boardsec" ref={boardRef}>
        <div className="mt-zt-toolbar">
          <div className="mt-seg" role="group" aria-label="View">
            <button type="button" aria-pressed={view === "board"} onClick={() => view !== "board" && swap()}><Icon name="feature" />Swimlanes</button>
            <button type="button" aria-pressed={view === "table"} onClick={() => view !== "table" && swap()}><Icon name="framework" />Table</button>
          </div>
          <input className="mt-input" type="search" placeholder="Search tasks, swimlanes or check IDs" aria-label="Search tasks" value={q} onInput={(e) => setQ((e.target as HTMLInputElement).value)} />
          {FILTERS.map((f) => <FilterMenu key={f.key} def={f} value={filters[f.key]} onChange={(next) => setFilters((x) => ({ ...x, [f.key]: next }))} />)}
          <label className="mt-zt-tog"><input type="checkbox" checked={checkedOnly} onChange={(e) => setCheckedOnly((e.target as HTMLInputElement).checked)} />Only tasks Maester checks</label>
          {view === "table" && <button type="button" className="mt-btn" onClick={() => setCollapsed((c) => (c.size ? new Set() : new Set(pillar.areas.map((a) => `a:${a.id}`))))}>{collapsed.size ? "Expand all" : "Collapse all"}</button>}
        </div>
        <p className="mt-note">{anyFilter ? <>Showing {shown} of {plural(pillar.tasks.length, "task")}. <button type="button" className="mt-link mt-zt-linkbtn" onClick={clear}>Clear filters</button></> : view === "board" ? "Pick a functional area. Its tasks run left to right through the workshop's phases. Select a task to see its checks and the workshop's guidance." : `${plural(pillar.tasks.length, "task")} in ${plural(pillar.areas.length, "functional area")}. Select a task to see its checks and the workshop's guidance.`}</p>

        {view === "table" ? (
          <div className="mt-zt-grid">
            <table className="mt-table">
              <thead><tr>{COLUMNS.map((c) => (
                <th key={c.key} className={c.sm ? "mt-hide-sm" : undefined} aria-sort={sort.key === c.key ? (sort.dir > 0 ? "ascending" : "descending") : "none"}>
                  <button type="button" onClick={() => setSort((s) => (s.key !== c.key ? { key: c.key, dir: 1 } : s.dir > 0 ? { key: c.key, dir: -1 } : { key: null, dir: 1 }))}>{c.label}<span className="mt-zt-sort" aria-hidden="true">{sort.key === c.key ? (sort.dir > 0 ? "↑" : "↓") : "↕"}</span></button>
                </th>))}</tr></thead>
              <tbody>
                {pillar.areas.map((a) => {
                  const ts = a.tasks.filter(match)
                  if (!ts.length) return null
                  const ak = `a:${a.id}`, aOpen = !collapsed.has(ak)
                  return [
                    <tr key={ak} className="grp mt-zt-area" onClick={() => toggle(ak)}>
                      <td colSpan={2}><span className="mt-zt-gcell"><button type="button" className="mt-zt-chev" aria-expanded={aOpen} aria-label={`${aOpen ? "Collapse" : "Expand"} ${a.name}`} onClick={(e) => { e.stopPropagation(); toggle(ak) }}><Icon name="chevron" /></button>
                        {plan.icon(a.icon) ? <img className="mt-zt-aico" src={plan.icon(a.icon)!} alt="" /> : null}<b>{a.name}</b><span className="mt-muted">{ts.length}</span></span></td>
                      <td colSpan={6}><span className="mt-zt-gcell"><Rollup tasks={a.tasks} /><span className="mt-muted mt-hide-sm">{rollText(a.tasks)}</span>
                        <button type="button" className="mt-link mt-zt-linkbtn" onClick={(e) => { e.stopPropagation(); setArea(a.id, "board") }}>Swimlanes</button></span></td>
                    </tr>,
                    ...(aOpen ? a.lanes.flatMap((l) => {
                      const lt = l.tasks.filter(match)
                      if (!lt.length) return []
                      const lk = `l:${l.key}`, lOpen = !collapsed.has(lk)
                      return [
                        <tr key={lk} className="mt-zt-lanerow" onClick={() => toggle(lk)}>
                          <td colSpan={2}><span className="mt-zt-gcell"><button type="button" className="mt-zt-chev" aria-expanded={lOpen} aria-label={`${lOpen ? "Collapse" : "Expand"} ${l.name}`} onClick={(e) => { e.stopPropagation(); toggle(lk) }}><Icon name="chevron" /></button><b>{l.name}</b><span className="mt-muted">{lt.length}</span></span></td>
                          <td colSpan={6}><span className="mt-zt-gcell"><Rollup tasks={l.tasks} /><span className="mt-muted mt-hide-sm">{rollText(l.tasks)}</span></span></td>
                        </tr>,
                        ...(lOpen ? sortTasks(lt).map((t) => (
                          <tr key={t.id} id={`mt-zt-row-${t.id}`} className={`click mt-zt-task${selected === t.id ? " on" : ""}${t.st === "manual" ? " manual" : ""}`} onClick={() => (selected === t.id ? close() : open(t.id))}>
                            <td className="ttl"><span className="mt-zt-tcell"><TaskIcon plan={plan} task={t} /><button type="button" className="mt-zt-tname" aria-expanded={selected === t.id} onClick={(e) => { e.stopPropagation(); if (selected === t.id) close(); else open(t.id) }}>{t.name}</button>{t.origin === "maester" && <span className="mt-chip ember">Maester</span>}</span></td>
                            <td><StatusBadge st={t.st} /></td>
                            <td className="mt-hide-sm">{t.phase}</td>
                            <td className="mt-hide-sm"><Priority value={t.priority} /></td>
                            <td><CheckBar task={t} /></td>
                            <td className="mt-hide-sm"><Level value={t.effort} /></td>
                            <td className="mt-hide-sm"><Level value={t.userImpact} /></td>
                            <td className="mt-hide-sm mt-zt-lic">{t.license || <span className="mt-muted">–</span>}</td>
                          </tr>
                        )) : []),
                      ]
                    }) : []),
                  ]
                })}
                {!shown && <tr><td colSpan={8} className="mt-empty">No task matches. <button type="button" className="mt-link mt-zt-linkbtn" onClick={clear}>Clear filters</button></td></tr>}
              </tbody>
            </table>
          </div>
        ) : (
          <>
            <div className="mt-zt-areas" role="group" aria-label="Functional area">
              {pillar.areas.map((a) => {
                const ck = a.tasks.filter((t) => t.st !== "manual")
                const gaps = a.tasks.filter(isOpenTask).length
                return (
                  <button key={a.id} type="button" className="mt-zt-acard" aria-pressed={a.id === area} onClick={() => setArea(a.id)}>
                    <span className="t">{plan.icon(a.icon) ? <img className="mt-zt-aico" src={plan.icon(a.icon)!} alt="" /> : null}{a.name}</span>
                    <span className="mt-muted">{ck.filter((t) => t.st === "done").length} of {ck.length} checked done{gaps ? ` · ${gaps} to fix` : ""}</span>
                    <Rollup tasks={ck} />
                  </button>
                )
              })}
            </div>
            {(() => {
              const a = pillar.areas.find((x) => x.id === area)
              if (!a) return null
              const inLane = (t: Task) => !laneKey || t.laneKey === laneKey
              const n = a.tasks.filter((t) => inLane(t) && match(t)).length
              return <>
                {laneDef && <p className="mt-note">Showing the {laneDef.name} swimlane. <button type="button" className="mt-link mt-zt-linkbtn" onClick={() => setArea(a.id)}>Show every swimlane of {a.name}</button></p>}
                {n
                  ? <ZeroTrustBoard plan={plan} area={a} current={pillar.current} selected={selected} match={(t) => inLane(t) && match(t)} onSelect={(id) => (id === selected ? close() : open(id))} />
                  : <p className="mt-empty">No task in {laneDef ? laneDef.name : a.name} matches. <button type="button" className="mt-link mt-zt-linkbtn" onClick={clear}>Clear filters</button></p>}
              </>
            })()}
          </>
        )}
      </section>
      {plan.source?.Url && <p className="mt-note">The plan is Microsoft's <a className="mt-link" href={plan.source.Url} target="_blank" rel="noopener noreferrer">Zero Trust Workshop</a>{plan.source.Updated ? `, as of ${plan.source.Updated}` : ""}. Maester adds its own tests to the tasks they measure, and a few tasks the workshop does not have.</p>}
      <Footer />
      {task && <TaskPanel plan={plan} task={task} view={view} onGo={(id) => open(id, "link")} onSwap={swap} onClose={close} />}
    </div>
  )
}
