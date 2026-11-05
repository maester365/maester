// The defender's path in the report: the action plan's step groups and goal lanes, the overview card, "Before you
// fix this" and the rollout on a test page. Everything here reads the result's Steps and Goals as the engine wrote
// them (lib/defendersPath.ts); nothing works out a status, an order or a count of its own.

import { useEffect, useState } from "react"
import { Link } from "@/lib/router"
import { REASONS, fixCommand, type Model, type Row } from "@/lib/model"
import {
  GOAL_STATUS_LABEL, GROUPS, NOT_CHECKED_REASON, READINESS_LABEL, STATUS_LABEL, measureFigure, prerequisiteMet, prerequisitesOf, testsThatRan,
  type DefendersPath, type Goal, type Step, type StepMeasure, type StepStatus,
} from "@/lib/defendersPath"
import { useReport } from "./ReportContext"
import { Cmd, Pill, ProductMark, formatDate, plural } from "./ui"

const STATUS_CLASS: Record<StepStatus, string> = { Done: "Passed", NotDone: "Failed", Unknown: "Investigate", NotChecked: "NotRun", NotApplicable: "Skipped" }
const KIND_LABEL: Record<string, string> = { Requires: "Required", RequiresOneOf: "One of these", RecommendedFirst: "Recommended first", Conflicts: "Must be off" }

export const StepPill = ({ status }: { status: StepStatus }) => <span className={`mt-pill mt-r-${STATUS_CLASS[status]}`}>{STATUS_LABEL[status]}</span>

function Readiness({ step }: { step: Step }) {
  // "Ready" on a step this run could not check says nothing the group heading doesn't.
  if (!step.Readiness || (step.Readiness === "Ready" && step.Status !== "NotDone")) return null
  const tone = step.Readiness === "Ready" ? " good" : step.Readiness === "Blocked" ? " bad" : " warn"
  return <span className={`mt-badge${tone}`}>{READINESS_LABEL[step.Readiness]}</span>
}

/** The steps a test verifies: the result's Steps that list it, then any other step its row names. */
export function stepsOfRow(model: Model, t: Row): Step[] {
  const path = model.path
  if (!path) return []
  const out = [...path.stepsOfTest(t.Id)]
  for (const id of t.Step) { const s = path.step(id); if (s && !out.includes(s)) out.push(s) }
  return out
}

/** The steps a failed test waits for, when its step is Blocked. */
export function blockedStepsOf(model: Model, t: Row): Step[] {
  return stepsOfRow(model, t).filter((s) => s.Readiness === "Blocked")
}

// Opens the step's group when the card is past its first few, then scrolls to the card.
function scrollToStep(id: string) {
  window.dispatchEvent(new CustomEvent("mt-step", { detail: id }))
  window.setTimeout(() => document.getElementById(`mt-step-${id}`)?.scrollIntoView({ behavior: "smooth", block: "start" }), 30)
}

function StepRef({ path, id, linked }: { path: DefendersPath; id: string; linked?: boolean }) {
  const s = path.step(id)
  const label = s ? s.Title : id
  if (linked && s && path.group(s)) return <button type="button" className="mt-steplink" onClick={() => scrollToStep(id)}>{label}</button>
  return <span>{label}</span>
}

function TestRef({ id }: { id: string }) {
  const { model, openTest } = useReport()
  return model.byId.has(id)
    ? <a href={`#${id}`} className="mt-link mt-mono" style={{ fontSize: 12 }} onClick={(e) => { e.preventDefault(); openTest(id) }}>{id}</a>
    : <span className="mt-mono mt-muted" style={{ fontSize: 12 }}>{id}</span>
}

function typeName(type: string, n: number) {
  const name = type ? type.replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase() : "object"
  return n === 1 ? name : `${name}s`
}

/** A measure: its figure against the share needed, its caveat and the objects that fall short. */
export function MeasureView({ measure, title }: { measure: StepMeasure; title: string }) {
  if (measure.ReasonCode) {
    const [head, text] = REASONS[measure.ReasonCode] || [measure.ReasonCode, ""]
    return <div className="mt-measure"><div className="mt-measure-h"><b>{title}</b><span className="mt-muted">Couldn't be read</span></div><p className="mt-note">{head}. {text}</p></div>
  }
  const share = measure.Share ?? 0
  const type = measure.Objects[0]?.Type || ""
  return (
    <div className="mt-measure">
      <div className="mt-measure-h"><b>{title}</b><span className={`mt-num ${measure.Met ? "mt-down" : "mt-up"}`}>{measureFigure(measure)}</span></div>
      <div className="mt-meter" role="img" aria-label={`${share}%${measure.MinimumShare !== null ? `, ${measure.MinimumShare}% needed` : ""}`}>
        <i className={measure.Met ? "met" : ""} style={{ width: `${Math.min(100, Math.max(0, share))}%` }} />
        {measure.MinimumShare !== null && <b style={{ left: `${measure.MinimumShare}%` }} />}
      </div>
      {measure.Caveat && <p className="mt-note">{measure.Caveat}</p>}
      {measure.ObjectCount > 0 && (
        <details className="mt-more">
          <summary>{measure.ObjectCount} {typeName(type, measure.ObjectCount)} fall short</summary>
          <ul className="mt-objlist">{measure.Objects.slice(0, 20).map((o) => <li key={o.Id}>{o.DisplayName}</li>)}</ul>
          {measure.ObjectCount > Math.min(20, measure.Objects.length) && <p className="mt-note">{measure.ObjectCount - Math.min(20, measure.Objects.length)} more{measure.Objects.length < measure.ObjectCount ? `. The result keeps the first ${measure.Objects.length}` : " in the result"}.</p>}
        </details>
      )}
      {measure.ReadAt && <p className="mt-note">Read {formatDate(measure.ReadAt, true)}.</p>}
    </div>
  )
}

function Sources({ step }: { step: Step }) {
  if (!step.Sources.length) return null
  return (
    <ul className="mt-sources">
      {step.Sources.map((s, i) => (
        <li key={i}>
          {s.Url ? <a className="mt-link" href={s.Url} target="_blank" rel="noopener noreferrer">{s.Url.replace(/^https:\/\/learn\.microsoft\.com\//, "Microsoft Learn: ").replace(/^https?:\/\//, "")} ↗</a> : <b>Maintainer: {s.Maintainer}</b>}
          {s.Note && <span>{s.Note}</span>}
        </li>
      ))}
    </ul>
  )
}

/** Why this run could not tell whether a step is done, and the command that would. */
function NotKnown({ step }: { step: Step }) {
  const { model } = useReport()
  if (step.Status === "NotChecked") {
    return (
      <div className="mt-stepline">
        <span>{step.Reason === "NoCheck" && step.Unchecked ? step.Unchecked : NOT_CHECKED_REASON[step.Reason || ""] || "Not checked in this run."}</span>
        {step.Earlier && <span>{STATUS_LABEL[step.Earlier.Status]} in an earlier run on {formatDate(step.Earlier.ExecutedAt)}.</span>}
        {step.Reason === "NotSelected" && <Cmd command={`Invoke-Maester -Step ${step.Id}`} wrap />}
      </div>
    )
  }
  if (step.Status !== "Unknown") return null
  const unsure = testsThatRan(step).filter((t) => t.Result !== "Passed" && t.Result !== "Failed")
  const codes = [...new Set([...unsure.map((t) => t.ReasonCode || (t.Result === "Error" ? "TestError" : t.Result)), ...(step.Measure?.ReasonCode ? [step.Measure.ReasonCode] : [])])]
  const commands = [...new Set(unsure.map((t) => { const row = model.byId.get(t.Id); return row ? fixCommand(row) : "" }).filter(Boolean))]
  return (
    <div className="mt-stepline">
      <span>This run could not tell: {codes.map((c) => (REASONS[c] || [c])[0].toLowerCase()).join(", ") || "a check needs a closer look"}.</span>
      {commands.slice(0, 2).map((c) => <Cmd key={c} command={c} wrap />)}
    </div>
  )
}

export function StepCard({ step }: { step: Step }) {
  const { model } = useReport()
  const path = model.path!
  const ran = testsThatRan(step)
  const failed = step.Tests.filter((t) => t.Result === "Failed")
  const unlocked = step.Unlocks.map((id) => path.step(id)).filter((s): s is Step => !!s)
  const unlockedFailures = unlocked.reduce((n, s) => n + s.Tests.filter((t) => t.Result === "Failed").length, 0)
  return (
    <article id={`mt-step-${step.Id}`} className="mt-card mt-step">
      <div className="mt-step-h">
        <ProductMark product={step.Product} size="sm" />
        <b>{step.Title}</b>
        <span className="mt-step-tags"><StepPill status={step.Status} /><Readiness step={step} /></span>
      </div>
      {step.Summary && <p className="mt-step-sum">{step.Summary}</p>}
      {step.Measure && <MeasureView measure={step.Measure} title="Measure" />}
      {step.BlockedBy.length > 0 && <div className="mt-stepline bad"><b>Blocked by</b>{step.BlockedBy.map((id) => <StepRef key={id} path={path} id={id} linked />)}</div>}
      {step.Unconfirmed.length > 0 && <div className="mt-stepline"><b>Check first</b>{step.Unconfirmed.map((id) => <StepRef key={id} path={path} id={id} linked />)}</div>}
      <NotKnown step={step} />
      {step.Tests.length > 0 && (
        <div className="mt-steptests">
          <span className="mt-note">{failed.length ? `${plural(failed.length, "check")} failed · ` : ""}{ran.length} of {plural(step.Tests.length, "check")} ran</span>
          {step.Tests.map((t) => <span key={t.Id} className="mt-steptest"><TestRef id={t.Id} />{t.Result === "NotRun" ? <span className="mt-muted" style={{ fontSize: 12 }}>Not in this run</span> : <Pill result={t.Result} />}</span>)}
        </div>
      )}
      {unlocked.length > 0 && (
        <div className="mt-stepline good"><b>Unlocks {plural(unlocked.length, "step")}{unlockedFailures ? `, ${plural(unlockedFailures, "failed check")}` : ""}</b>{unlocked.map((s) => <StepRef key={s.Id} path={path} id={s.Id} linked />)}</div>
      )}
      {(step.Rollout.length > 0 || step.Sources.length > 0) && (
        <details className="mt-more">
          <summary>{step.Rollout.length ? "How to roll it out" : "Sources"}</summary>
          {step.Rollout.length > 0 && <ol className="mt-rollout">{step.Rollout.map((r, i) => <li key={i}>{r}</li>)}</ol>}
          <Sources step={step} />
        </details>
      )}
    </article>
  )
}

const GROUP_LIMIT = 6

function Group({ group, steps }: { group: (typeof GROUPS)[number]; steps: Step[] }) {
  const [all, setAll] = useState(false)
  // A link to a step's card shows the whole group, so the card is there to scroll to.
  useEffect(() => {
    const show = (e: Event) => { if (steps.some((s) => s.Id === (e as CustomEvent<string>).detail)) setAll(true) }
    window.addEventListener("mt-step", show)
    return () => window.removeEventListener("mt-step", show)
  }, [steps])
  const shown = all ? steps : steps.slice(0, GROUP_LIMIT)
  return (
    <section className="mt-sec">
      <div className="mt-sechead"><h2 className="mt-h2">{group.title} <span className="mt-muted mt-num">· {steps.length}</span></h2></div>
      <p className="mt-note" style={{ marginTop: -8 }}>{group.text}</p>
      <div className="mt-grid mt-g2" style={{ alignItems: "start" }}>{shown.map((s) => <StepCard key={s.Id} step={s} />)}</div>
      {steps.length > shown.length && <button type="button" className="mt-btn" style={{ alignSelf: "flex-start" }} onClick={() => setAll(true)}>Show {steps.length - shown.length} more</button>}
    </section>
  )
}

/** The action plan's three groups of steps, in Rank order. */
export function PathGroups() {
  const { model } = useReport()
  const path = model.path
  if (!path) return null
  return <>{GROUPS.map((g) => (path.groups[g.key].length ? <Group key={g.key} group={g} steps={path.groups[g.key]} /> : null))}</>
}

function Lane({ goal }: { goal: Goal }) {
  const { model } = useReport()
  const path = model.path!
  const steps = goal.Steps.map((id) => ({ id, step: path.step(id) }))
  const open = steps.filter(({ step }) => step && (step.Status === "Unknown" || step.Status === "NotChecked")).length
  return (
    <div className="mt-lane">
      <div className="mt-lane-h">
        <span><b>{goal.Title}</b><span className="mt-muted"> · {goal.Done} of {plural(goal.Applicable, "step")} done{open ? ` · ${open} to check` : ""}</span></span>
        <span className={`mt-badge${goal.Status === "Done" ? " good" : ""}`}>{GOAL_STATUS_LABEL[goal.Status]}</span>
      </div>
      <ol className="mt-lane-steps">
        {steps.map(({ id, step }) => (
          <li key={id} className={step ? `st-${step.Status}` : "st-none"}>
            <i aria-hidden="true" />
            {step && path.group(step)
              ? <button type="button" onClick={() => scrollToStep(id)}>{step.Title}</button>
              : <span>{step ? step.Title : id}</span>}
            <small>{step ? STATUS_LABEL[step.Status] : "Not in this run"}{id === goal.Step ? " · goal" : ""}</small>
          </li>
        ))}
      </ol>
    </div>
  )
}

/** A lane for each goal in scope, its steps in the order the result gives them. */
export function GoalLanes() {
  const { model } = useReport()
  const goals = model.path?.goals || []
  if (!goals.length) return null
  return (
    <section className="mt-sec">
      <div className="mt-sechead"><h2 className="mt-h2">Goals</h2></div>
      <p className="mt-note" style={{ marginTop: -8 }}>Each goal is one outcome and the steps that lead to it, prerequisites first.</p>
      <div className="mt-card mt-lanes">{goals.map((g) => <Lane key={g.Id} goal={g} />)}</div>
    </section>
  )
}

/** The overview's card: how many steps are ready now, blocked or to check first. */
export function PathCard() {
  const { model } = useReport()
  const path = model.path
  if (!path || model.focused) return null
  const counts: [string, number, string][] = [["Ready now", path.groups.ready.length, "mt-down"], ["Blocked", path.groups.blocked.length, "mt-up"], ["Check first", path.groups.check.length, ""]]
  return (
    <section className="mt-card mt-pad mt-sec">
      <div className="mt-sechead"><h2 className="mt-h2">Defender's path</h2><Link to="/plan">Open the action plan →</Link></div>
      <p className="mt-note" style={{ marginTop: -6 }}>The order to make changes in, so that each fix has what it depends on. Across {plural(path.goals.length, "goal")}.</p>
      <div className="mt-pathcounts">
        {counts.map(([label, n, tone]) => <Link key={label} to="/plan" className="mt-count"><b className={`mt-num ${n ? tone : ""}`}>{n}</b><span>{label}</span></Link>)}
      </div>
    </section>
  )
}

function PrereqSource({ step }: { step: Step }) {
  const ran = testsThatRan(step)
  if (step.Measure && !step.Measure.ReasonCode) return <MeasureView measure={step.Measure} title="Measure" />
  if (ran.length) return <span className="mt-note">{ran.map((t, i) => <span key={t.Id}>{i ? ", " : ""}<TestRef id={t.Id} /> {t.Result === "NotRun" ? "not run" : t.Result.toLowerCase()}</span>)} in this run</span>
  if (step.Earlier) return <span className="mt-note">{STATUS_LABEL[step.Earlier.Status]} in an earlier run on {formatDate(step.Earlier.ExecutedAt)}{step.Earlier.File ? ` (${step.Earlier.File})` : ""}</span>
  if (step.Measure?.ReasonCode) return <span className="mt-note">Its measure couldn't be read: {(REASONS[step.Measure.ReasonCode] || [step.Measure.ReasonCode])[0].toLowerCase()}</span>
  return <span className="mt-note">{step.Reason === "NoCheck" && step.Unchecked ? step.Unchecked : NOT_CHECKED_REASON[step.Reason || ""] || "Not checked in this run."}</span>
}

/** On a test page: the prerequisites of the test's step that stand in the way, and the command that checks them. */
export function BeforeYouFix({ test }: { test: Row }) {
  const { model } = useReport()
  const path = model.path
  if (!path || test.Result === "Passed") return null
  const blocks = stepsOfRow(model, test).map((step) => ({ step, prereqs: prerequisitesOf(step).map((p) => ({ ...p, step: path.step(p.id) })) }))
    .filter((b) => b.prereqs.some((p) => !prerequisiteMet(p.step, p.kind)))
  if (!blocks.length) return null
  return (
    <section className="mt-before">
      <h3>Before you fix this</h3>
      {blocks.map(({ step, prereqs }) => {
        const open = prereqs.filter((p) => !prerequisiteMet(p.step, p.kind)).length
        return (
          <div key={step.Id} className="mt-sec" style={{ gap: 10 }}>
            <p className="mt-before-lead">This test checks <b>{step.Title.charAt(0).toLowerCase() + step.Title.slice(1)}</b>. {step.Readiness === "Blocked" ? "It is blocked: " : ""}{plural(open, "of its prerequisites is", "of its prerequisites are")} not done or not confirmed.</p>
            <div className="mt-prereqs">
              {prereqs.map((p) => (
                <div key={p.id} className="mt-prereq">
                  <span className="mt-prereq-h">{p.step ? <StepPill status={p.step.Status} /> : <span className="mt-pill mt-r-none">Not in this run</span>}<b>{p.step ? p.step.Title : p.id}</b><span className="mt-muted" style={{ fontSize: 12 }}>{KIND_LABEL[p.kind]}</span></span>
                  {p.step && <PrereqSource step={p.step} />}
                </div>
              ))}
            </div>
          </div>
        )
      })}
      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        <span className="mt-note">Check this test and everything it depends on:</span>
        <Cmd command={`Invoke-Maester -TestId ${test.Id} -IncludePrerequisites`} wrap />
      </div>
    </section>
  )
}

/** The How to fix tab's rollout: how to switch each of the test's steps on safely, with its sources. */
export function StepRollout({ test }: { test: Row }) {
  const { model } = useReport()
  const steps = stepsOfRow(model, test).filter((s) => s.Rollout.length || s.Sources.length)
  if (!steps.length) return null
  return (
    <>
      {steps.map((s) => (
        <section key={s.Id}>
          <h3>Roll it out safely</h3>
          <p className="mt-note" style={{ marginBottom: 8 }}>{s.Title}</p>
          {s.Rollout.length > 0 && <ol className="mt-rollout">{s.Rollout.map((r, i) => <li key={i}>{r}</li>)}</ol>}
          <Sources step={s} />
        </section>
      ))}
    </>
  )
}
