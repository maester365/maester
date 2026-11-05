// The defender's path: the result's Steps and Goals (docs/proposals/defenders-path.md, section 7.2), read into
// types the views use. This is the only file that knows their JSON shape, so a change to it is fixed here.
// The engine works out every status, readiness, rank and count; the report shows them as written and works out
// nothing itself. A result with no Steps has no path, and every view stays as it was.

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Raw = Record<string, any>

export type StepStatus = "Done" | "NotDone" | "Unknown" | "NotChecked" | "NotApplicable"
export type StepReadiness = "Ready" | "Blocked" | "Unconfirmed"
export type GoalStatus = "Done" | "InProgress" | "NotStarted"

export interface StepTest {
  Id: string
  Result: string
  ReasonCode: string | null
}

export interface MeasureObject {
  Type: string
  Id: string
  DisplayName: string
}

export interface StepMeasure {
  Key: string
  Count: number | null
  Total: number | null
  Share: number | null
  MinimumShare: number | null
  Met: boolean | null
  ReadAt: string | null
  Caveat: string | null
  ObjectCount: number
  Objects: MeasureObject[]
  /** Why the figure could not be read, with the codes a skipped test uses. Null when it was read. */
  ReasonCode: string | null
}

export interface StepEarlier {
  Status: StepStatus
  ExecutedAt: string
  File: string | null
}

export interface StepSource {
  Url: string | null
  Maintainer: string | null
  Note: string
  Reviewed: string | null
}

export interface Step {
  Id: string
  Title: string
  Summary: string
  Product: string | null
  Goals: string[]
  Status: StepStatus
  /** Why a step is Not checked: NotSelected, MeasureOff or NoCheck. */
  Reason: string | null
  /** Set on steps that are Not done, Unknown or Not checked. */
  Readiness: StepReadiness | null
  BlockedBy: string[]
  Unconfirmed: string[]
  Unlocks: string[]
  Rank: number
  Tests: StepTest[]
  Earlier: StepEarlier | null
  Measure: StepMeasure | null
  Requires: string[]
  RequiresOneOf: string[][]
  RecommendedFirst: string[]
  Conflicts: string[]
  OnlyWhen: string[]
  Rollout: string[]
  Sources: StepSource[]
  /** The catalogue's sentence on why Maester can't check the step, when the result carries it. */
  Unchecked: string | null
}

export interface Goal {
  Id: string
  Title: string
  Summary: string | null
  Step: string
  Steps: string[]
  Done: number
  Applicable: number
  Status: GoalStatus
}

/** The three groups the action plan shows, in this order. */
export type PathGroup = "ready" | "check" | "blocked"
export const GROUPS: { key: PathGroup; title: string; text: string }[] = [
  { key: "ready", title: "Ready now", text: "Not done, and nothing they depend on is missing. Start here." },
  { key: "check", title: "Check first", text: "This run could not tell whether these are done, or whether what they depend on is in place." },
  { key: "blocked", title: "Blocked", text: "Something they depend on is not done yet. Fix that first, or the change fails or locks users out." },
]

export const STATUS_LABEL: Record<StepStatus, string> = { Done: "Done", NotDone: "Not done", Unknown: "Unknown", NotChecked: "Not checked", NotApplicable: "Not applicable" }
export const READINESS_LABEL: Record<StepReadiness, string> = { Ready: "Ready", Blocked: "Blocked", Unconfirmed: "Check first" }
export const GOAL_STATUS_LABEL: Record<GoalStatus, string> = { Done: "Done", InProgress: "In progress", NotStarted: "Not started" }
// Not-checked reasons (section 6.1).
export const NOT_CHECKED_REASON: Record<string, string> = {
  NotSelected: "Its tests were not selected in this run.",
  MeasureOff: "The run config turned its measure off.",
  NoCheck: "Maester has no check for this yet.",
}

export interface DefendersPath {
  steps: Step[]
  goals: Goal[]
  step: (id: string) => Step | undefined
  /** The steps a test verifies, from the result's Steps. */
  stepsOfTest: (testId: string) => Step[]
  group: (s: Step) => PathGroup | null
  groups: Record<PathGroup, Step[]>
}

const text = (v: unknown) => (v === null || v === undefined ? "" : String(v))
const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : null)
// PowerShell writes a one-item list as a single value.
const arr = (v: unknown): unknown[] => (v === null || v === undefined ? [] : Array.isArray(v) ? v : [v])
const list = (v: unknown): string[] => arr(v).map(text).filter(Boolean)
const STATUSES: StepStatus[] = ["Done", "NotDone", "Unknown", "NotChecked", "NotApplicable"]
const status = (v: unknown): StepStatus => (STATUSES.includes(v as StepStatus) ? (v as StepStatus) : "Unknown")

function readMeasure(m: Raw | null | undefined): StepMeasure | null {
  if (!m || typeof m !== "object") return null
  const objects = arr(m.Objects).filter((o): o is Raw => !!o && typeof o === "object").map((o) => ({ Type: text(o.Type), Id: text(o.Id), DisplayName: text(o.DisplayName) || text(o.Id) }))
  return {
    Key: text(m.Key), Count: num(m.Count), Total: num(m.Total), Share: num(m.Share), MinimumShare: num(m.MinimumShare),
    Met: typeof m.Met === "boolean" ? m.Met : null, ReadAt: m.ReadAt ? text(m.ReadAt) : null, Caveat: m.Caveat ? text(m.Caveat) : null,
    ObjectCount: num(m.ObjectCount) ?? objects.length, Objects: objects, ReasonCode: m.ReasonCode ? text(m.ReasonCode) : null,
  }
}

function readStep(s: Raw): Step {
  const readiness = ["Ready", "Blocked", "Unconfirmed"].includes(s.Readiness) ? (s.Readiness as StepReadiness) : null
  return {
    Id: text(s.Id), Title: text(s.Title) || text(s.Id), Summary: text(s.Summary), Product: s.Product ? text(s.Product) : null,
    Goals: list(s.Goals), Status: status(s.Status), Reason: s.Reason ? text(s.Reason) : null, Readiness: readiness,
    BlockedBy: list(s.BlockedBy), Unconfirmed: list(s.Unconfirmed), Unlocks: list(s.Unlocks), Rank: num(s.Rank) ?? Number.MAX_SAFE_INTEGER,
    Tests: arr(s.Tests).filter((t): t is Raw => !!t && typeof t === "object").map((t) => ({ Id: text(t.Id), Result: text(t.Result) || "NotRun", ReasonCode: t.ReasonCode ? text(t.ReasonCode) : null })),
    Earlier: s.Earlier && s.Earlier.ExecutedAt ? { Status: status(s.Earlier.Status), ExecutedAt: text(s.Earlier.ExecutedAt), File: s.Earlier.File ? text(s.Earlier.File) : null } : null,
    Measure: readMeasure(s.Measure),
    Requires: list(s.Requires),
    // A list of groups. PowerShell may write a single group, or a group of one, without its brackets.
    RequiresOneOf: (() => { const g = arr(s.RequiresOneOf); return g.length && !Array.isArray(g[0]) ? [list(g)] : g.map(list).filter((x) => x.length) })(),
    RecommendedFirst: list(s.RecommendedFirst), Conflicts: list(s.Conflicts), OnlyWhen: list(s.OnlyWhen), Rollout: list(s.Rollout),
    Sources: arr(s.Sources).filter((o): o is Raw => !!o && typeof o === "object").map((o) => ({ Url: o.Url ? text(o.Url) : null, Maintainer: o.Maintainer ? text(o.Maintainer) : null, Note: text(o.Note), Reviewed: o.Reviewed ? text(o.Reviewed) : null })),
    Unchecked: s.Unchecked ? text(s.Unchecked) : null,
  }
}

function readGoal(g: Raw): Goal {
  const st = text(g.Status)
  return {
    Id: text(g.Id), Title: text(g.Title) || text(g.Id), Summary: g.Summary ? text(g.Summary) : null, Step: text(g.Step), Steps: list(g.Steps),
    Done: num(g.Done) ?? 0, Applicable: num(g.Applicable) ?? 0, Status: (["Done", "InProgress", "NotStarted"].includes(st) ? st : "NotStarted") as GoalStatus,
  }
}

/** The group a step is listed in: Blocked by its readiness; Ready now when it is ready and not done; Check first
 *  when it is unconfirmed, or ready but this run could not tell whether it is done. Done and Not applicable steps
 *  are in no group. */
function groupOf(s: Step): PathGroup | null {
  if (s.Status === "Done" || s.Status === "NotApplicable" || !s.Readiness) return null
  if (s.Readiness === "Blocked") return "blocked"
  if (s.Readiness === "Ready" && s.Status === "NotDone") return "ready"
  return "check"
}

/** The result's defender's path, or null when it has no Steps. */
export function readDefendersPath(result: Raw | null | undefined): DefendersPath | null {
  const rawSteps = arr(result?.Steps).filter((s): s is Raw => !!s && typeof s === "object" && !!(s as Raw).Id)
  if (!rawSteps.length) return null
  const steps = rawSteps.map(readStep).sort((a, b) => a.Rank - b.Rank)
  const goals = arr(result?.Goals).filter((g): g is Raw => !!g && typeof g === "object" && !!(g as Raw).Id).map(readGoal)
  const byId = new Map(steps.map((s) => [s.Id, s]))
  const byTest = new Map<string, Step[]>()
  for (const s of steps) for (const t of s.Tests) { if (!byTest.has(t.Id)) byTest.set(t.Id, []); byTest.get(t.Id)!.push(s) }
  const groups: Record<PathGroup, Step[]> = { ready: [], check: [], blocked: [] }
  for (const s of steps) { const g = groupOf(s); if (g) groups[g].push(s) }
  return { steps, goals, step: (id) => byId.get(id), stepsOfTest: (id) => byTest.get(id) || [], group: groupOf, groups }
}

/** Every prerequisite of a step, as the catalogue relates them, in the order the result lists them. */
export function prerequisitesOf(s: Step): { id: string; kind: "Requires" | "RequiresOneOf" | "RecommendedFirst" | "Conflicts" }[] {
  const out: { id: string; kind: "Requires" | "RequiresOneOf" | "RecommendedFirst" | "Conflicts" }[] = []
  const seen = new Set<string>()
  const add = (id: string, kind: (typeof out)[number]["kind"]) => { if (!seen.has(id)) { seen.add(id); out.push({ id, kind }) } }
  for (const id of s.Requires) add(id, "Requires")
  for (const g of s.RequiresOneOf) for (const id of g) add(id, "RequiresOneOf")
  for (const id of s.RecommendedFirst) add(id, "RecommendedFirst")
  for (const id of s.Conflicts) add(id, "Conflicts")
  return out
}

/** Whether a prerequisite stands in the way: anything but Done or Not applicable (a conflict: anything but off). */
export const prerequisiteMet = (p: Step | undefined, kind: string) => (kind === "Conflicts" ? p?.Status !== "Done" : !!p && (p.Status === "Done" || p.Status === "NotApplicable"))

/** A measure's figure in words, such as "71% (412 of 580), 95% needed". Empty when it could not be read. */
export function measureFigure(m: StepMeasure): string {
  if (m.ReasonCode || m.Share === null) return ""
  const of = m.Count !== null && m.Total !== null ? ` (${m.Count} of ${m.Total})` : ""
  return `${m.Share}%${of}${m.MinimumShare !== null ? `, ${m.MinimumShare}% needed` : ""}`
}

/** The verifying tests that ran in this run (anything but NotRun). */
export const testsThatRan = (s: Step) => s.Tests.filter((t) => t.Result !== "NotRun")
