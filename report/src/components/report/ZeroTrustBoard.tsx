// One functional area of the Zero Trust plan as a board: the area's swimlanes are rows, the workshop's three
// phases are columns, and each task is a card in its lane and phase, coloured by what this run found. On a phone
// the columns stack under each lane.

import { PHASES, STATUS_LABEL, blockersOf, type Area, type Plan, type Task } from "@/lib/zeroTrust"

export function ZeroTrustBoard({ plan, area, current, selected, match, onSelect }: {
  plan: Plan
  area: Area
  /** The phase the reader is in, marked on its column. */
  current: string
  selected: string | null
  /** Tasks the filters keep; the others are left off the board. */
  match: (t: Task) => boolean
  onSelect: (id: string) => void
}) {
  const lanes = area.lanes.map((l) => ({ ...l, shown: l.tasks.filter(match) })).filter((l) => l.shown.length)
  return (
    <div className="mt-zt-boardwrap">
      <div className="mt-zt-legend" aria-hidden="true">
        {(["done", "partial", "notdone", "unknown", "manual"] as const).map((s) => <span key={s}><i className={`mt-zt-dot s-${s}`} />{STATUS_LABEL[s]}</span>)}
      </div>
      <div className="mt-zt-board" role="table" aria-label={`${area.name} by swimlane and phase`}>
        <div className="mt-zt-brow head" role="row">
          <div className="ph lane" role="columnheader">Swimlane</div>
          {PHASES.map((p) => {
            const ts = area.tasks.filter((t) => t.phase === p && t.st !== "manual")
            return (
              <div key={p} role="columnheader" className={`ph${p === current ? " cur" : ""}`}>
                <b>{p}</b>{p === current ? <span className="here">You are here</span> : null}
                <span>{ts.length ? `${ts.filter((t) => t.st === "done").length} of ${ts.length} done` : "Nothing checked"}</span>
              </div>
            )
          })}
        </div>
        {lanes.map((l) => {
          const ck = l.tasks.filter((t) => t.st !== "manual")
          const review = l.tasks.length - ck.length
          return (
            <div key={l.key} className="mt-zt-brow" role="row">
              <div className="lane" role="rowheader">
                <b>{l.name}</b>
                <span>{ck.length ? `${ck.filter((t) => t.st === "done").length} of ${ck.length} done` : "Nothing Maester checks"}{review ? ` · ${review} to review` : ""}</span>
              </div>
              {PHASES.map((p) => {
                const ts = l.shown.filter((t) => t.phase === p)
                return (
                  <div key={p} role="cell" className={`cell${ts.length ? "" : " none"}${p === current ? " cur" : ""}`}>
                    <span className="phl">{p}</span>
                    {ts.map((t) => <Card key={t.id} plan={plan} task={t} selected={t.id === selected} onSelect={onSelect} />)}
                  </div>
                )
              })}
            </div>
          )
        })}
      </div>
    </div>
  )
}

function Card({ plan, task: t, selected, onSelect }: { plan: Plan; task: Task; selected: boolean; onSelect: (id: string) => void }) {
  const b = blockersOf(plan, t)
  const sub = t.st === "manual" ? "Review yourself" : t.st === "unknown" ? "Couldn't check" : `${t.passes.length} of ${t.ran.length} checks pass`
  return (
    <button type="button" id={`mt-zt-card-${t.id}`} className={`mt-zt-card s-${t.st}${selected ? " sel" : ""}`} aria-pressed={selected}
      aria-label={`${t.name}: ${STATUS_LABEL[t.st]}`} onClick={() => onSelect(t.id)}>
      <TaskIcon plan={plan} task={t} />
      <span className="nm">{t.name}{t.origin === "maester" && <span className="mt-chip ember">Maester</span>}</span>
      <span className="sub">{sub}{t.priority ? ` · ${t.priority}` : ""}{b.length ? ` · after ${b[0].name}${b.length > 1 ? ` +${b.length - 1}` : ""}` : ""}</span>
    </button>
  )
}

export function TaskIcon({ plan, task, size = "" }: { plan: Plan; task: Task; size?: "" | "lg" }) {
  const src = plan.icon(task.icon)
  return (
    <span className={`mt-zt-ico ${size}`} aria-hidden="true">
      {src ? <img src={src} alt="" /> : <i />}
      <i className={`mt-zt-badge s-${task.st}`} />
    </span>
  )
}
