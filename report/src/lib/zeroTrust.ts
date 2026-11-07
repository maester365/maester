// The Zero Trust plan: Microsoft's Zero Trust Workshop (pillars, functional areas, swimlanes and tasks in three
// phases) with each task's status worked out from the checks of this run that measure it. The Zero Trust
// Assessment pack attaches the plan to the report as JSON (Add-MtReportAttachment -ContentType application/json,
// name "zero-trust-workshop"); this file reads it and joins it to the run's rows by test ID.

import { useEffect, useMemo, useState } from "react"
import { decodeAttachment, getDataAttachment, type ReportAttachment } from "@/lib/reportAttachments"
import type { Model, Row } from "@/lib/model"

export const WORKSHOP_ATTACHMENT = "zero-trust-workshop"
export const WORKSHOP_SCHEMA = "maester.zero-trust-workshop/1"

export interface WorkshopCheckRef { Id: string; Source?: "microsoft" | "same-check" | "maester" | string; Via?: string }
export interface WorkshopTask {
  Id: string; Name: string; AreaId: string; Swimlane?: string; Phase?: string; Priority?: string; Effort?: string; UserImpact?: string
  License?: string; Cisa?: string; Dependencies?: string[]; Icon?: string; Doc?: string; Note?: string; Origin?: string; Checks?: WorkshopCheckRef[]
}
export interface WorkshopArea { Id: string; Name: string; Description?: string; Icon?: string }
export interface WorkshopPillar { Id: string; Name: string; Areas: WorkshopArea[]; Tasks: WorkshopTask[] }
export interface Workshop {
  Schema?: string
  Source?: { Name?: string; Url?: string; Updated?: string }
  Pillars: WorkshopPillar[]
  Icons?: Record<string, string>
}

// done: every check that ran passed. partial: some failed. notdone: all failed. unknown: none of its checks ran.
// manual: no check measures the task, so the reader reviews it.
export type TaskStatus = "done" | "partial" | "notdone" | "unknown" | "manual"
export const STATUSES: TaskStatus[] = ["notdone", "partial", "unknown", "done", "manual"]
export const STATUS_LABEL: Record<TaskStatus, string> = { done: "Done", partial: "Partly done", notdone: "Not done", unknown: "Couldn't check", manual: "Review yourself" }
export const STATUS_RANK: Record<TaskStatus, number> = { notdone: 0, partial: 1, unknown: 2, manual: 3, done: 4 }
export const PHASES = ["First", "Then", "Next"] as const
export const PHASE_RANK: Record<string, number> = { First: 0, Then: 1, Next: 2 }
export const LEVEL: Record<string, number> = { Low: 1, Medium: 2, High: 3 }
export const priorityRank = (p?: string) => (p && /^P\d$/.test(p) ? Number(p.slice(1)) : 9)

const PASSING = new Set(["Passed"])
const FAILING = new Set(["Failed", "Error", "Investigate"])

export interface Check extends WorkshopCheckRef {
  row: Row | null
  /** Passed, Failed, Error, Investigate, Skipped, NotRun, or "Missing" when the test is not in this run. */
  result: string
  title: string
}

export interface Task {
  id: string; name: string; areaId: string; swimlane: string; phase: string; priority: string | null; effort: string | null
  userImpact: string | null; license: string | null; cisa: string | null; dependencies: string[]; icon: string | null; doc: string
  note: string | null; origin: string; checks: Check[]
  st: TaskStatus; passes: Check[]; fails: Check[]; ran: Check[]; index: number; laneKey: string; pillarId: string
}
export interface Lane { name: string; key: string; tasks: Task[] }
export interface Area { id: string; name: string; description: string; icon: string | null; tasks: Task[]; lanes: Lane[] }
export interface Pillar {
  id: string; name: string; areas: Area[]; tasks: Task[]; byId: Map<string, Task>
  /** How many of the plan's checks are in this run. A pillar with none has nothing measured. */
  checksInRun: number
  current: (typeof PHASES)[number]
  next: Task[]
}
export interface Plan { source: Workshop["Source"]; pillars: Pillar[]; byId: Map<string, Task>; icon: (name: string | null | undefined) => string | null }

export function statusOf(checks: Check[]): TaskStatus {
  if (!checks.length) return "manual"
  const ran = checks.filter((c) => PASSING.has(c.result) || FAILING.has(c.result))
  if (!ran.length) return "unknown"
  const failed = ran.filter((c) => FAILING.has(c.result)).length
  if (!failed) return "done"
  return failed === ran.length ? "notdone" : "partial"
}

/** Tasks a task waits on that are not done yet. */
export const blockersOf = (plan: Plan, t: Task) => t.dependencies.map((d) => plan.byId.get(d)).filter((d): d is Task => !!d && d.st !== "done")
/** Tasks that list this one as a dependency. */
export const dependentsOf = (plan: Plan, t: Task) => {
  const p = plan.pillars.find((x) => x.id === t.pillarId)
  return (p ? p.tasks : []).filter((x) => x.dependencies.includes(t.id))
}

function clean(s: string | undefined | null) {
  return (s ?? "").replace(/\s+/g, " ").trim()
}

export function buildPlan(workshop: Workshop, model: Model): Plan {
  const icons = workshop.Icons || {}
  const iconCache = new Map<string, string | null>()
  const icon = (name: string | null | undefined) => {
    if (!name) return null
    if (!iconCache.has(name)) {
      const svg = icons[name]
      iconCache.set(name, svg ? `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}` : null)
    }
    return iconCache.get(name)!
  }
  const all = new Map<string, Task>()
  const pillars: Pillar[] = (workshop.Pillars || []).map((p) => {
    const tasks: Task[] = (p.Tasks || []).map((raw, index) => {
      const seen = new Set<string>()
      const checks: Check[] = []
      for (const ref of raw.Checks || []) {
        if (!ref?.Id || seen.has(ref.Id)) continue
        seen.add(ref.Id)
        const row = model.byId.get(ref.Id) || null
        checks.push({ ...ref, row, result: row ? row.Result : "Missing", title: row?.Title || ref.Id })
      }
      const st = statusOf(checks)
      const ran = checks.filter((c) => PASSING.has(c.result) || FAILING.has(c.result))
      return {
        id: raw.Id, name: clean(raw.Name) || raw.Id, areaId: raw.AreaId, swimlane: clean(raw.Swimlane), phase: PHASES.includes(raw.Phase as never) ? raw.Phase! : "Then",
        priority: raw.Priority || null, effort: raw.Effort || null, userImpact: raw.UserImpact || null, license: raw.License || null, cisa: raw.Cisa || null,
        dependencies: (raw.Dependencies || []).filter(Boolean), icon: raw.Icon || null, doc: raw.Doc || "", note: raw.Note || null, origin: raw.Origin || "workshop",
        checks, st, ran, passes: checks.filter((c) => PASSING.has(c.result)), fails: checks.filter((c) => FAILING.has(c.result)), index, laneKey: "", pillarId: p.Id,
      }
    })
    for (const t of tasks) all.set(t.id, t)
    const areas: Area[] = (p.Areas || []).map((a) => {
      const ts = tasks.filter((t) => t.areaId === a.Id)
      const lanes: Lane[] = []
      for (const t of ts) {
        const name = t.swimlane || a.Name
        let lane = lanes.find((l) => l.name === name)
        if (!lane) lanes.push((lane = { name, key: `${a.Id}|${name}`, tasks: [] }))
        lane.tasks.push(t)
        t.laneKey = lane.key
      }
      return { id: a.Id, name: clean(a.Name), description: clean(a.Description), icon: a.Icon || null, tasks: ts, lanes }
    }).filter((a) => a.tasks.length)
    const checkable = tasks.filter((t) => t.st !== "manual")
    const current = PHASES.find((ph) => checkable.some((t) => t.phase === ph && t.st !== "done")) || "Next"
    return { id: p.Id, name: p.Name, areas, tasks, byId: new Map(tasks.map((t) => [t.id, t])), checksInRun: tasks.reduce((n, t) => n + t.checks.filter((c) => c.row).length, 0), current, next: [] }
  })
  const plan: Plan = { source: workshop.Source, pillars, byId: all, icon }
  for (const p of pillars) {
    p.next = p.tasks
      .filter((t) => t.st === "notdone" || t.st === "partial")
      .sort((a, b) => PHASE_RANK[a.phase] - PHASE_RANK[b.phase] || blockersOf(plan, a).length - blockersOf(plan, b).length || priorityRank(a.priority ?? undefined) - priorityRank(b.priority ?? undefined) || b.fails.length - a.fails.length || a.index - b.index)
      .slice(0, 6)
  }
  return plan
}

/** The plan attached to this result, if the Zero Trust Assessment pack attached one. */
export function workshopAttachment(model: Model, name = WORKSHOP_ATTACHMENT): ReportAttachment | undefined {
  return getDataAttachment(model.result, name)
}

/** The plan in the attachment of this name, built with this run's results once the attachment is read. */
export function usePlan(model: Model, name = WORKSHOP_ATTACHMENT) {
  const attachment = workshopAttachment(model, name)
  const [state, setState] = useState<{ id: string; workshop: Workshop | null; error: string }>({ id: "", workshop: null, error: "" })
  useEffect(() => {
    if (!attachment) return
    let live = true
    loadWorkshop(attachment).then((w) => live && setState({ id: attachment.Id, workshop: w, error: "" }), (e) => live && setState({ id: attachment.Id, workshop: null, error: String(e?.message || e) }))
    return () => { live = false }
  }, [attachment])
  const current = attachment && state.id === attachment.Id ? state : null
  const plan = useMemo(() => (current?.workshop ? buildPlan(current.workshop, model) : null), [current?.workshop, model])
  return { attachment, plan, error: current?.error || "" }
}

const loaded = new Map<string, Promise<Workshop>>()

export function loadWorkshop(attachment: ReportAttachment): Promise<Workshop> {
  let p = loaded.get(attachment.Id)
  if (!p) {
    p = (async () => {
      if (import.meta.env.DEV && attachment.Id.startsWith("dev:")) return (await import("@/lib/sampleZeroTrust")).sampleWorkshop()
      const data = JSON.parse(await decodeAttachment(attachment)) as Workshop
      if (!data || !Array.isArray(data.Pillars)) throw new Error("The Zero Trust plan in this report is not in a form this report can read.")
      return data
    })()
    loaded.set(attachment.Id, p)
    p.catch(() => loaded.delete(attachment.Id))
  }
  return p
}

/** A task's checks in the order to read them: failing first, then the ones that passed, then the rest. */
export function orderedChecks(t: Task) {
  const rank = (c: Check) => (FAILING.has(c.result) ? 0 : PASSING.has(c.result) ? 1 : c.result === "Missing" ? 3 : 2)
  return [...t.checks].sort((a, b) => rank(a) - rank(b))
}

/** The task with the workshop doc's leftovers removed: front matter, iframes, the title and the effort lines. */
export function cleanDoc(md: string) {
  // The Markdown renderer sanitizes its output; this only tidies. Iframe tags are removed until none is left, so a
  // tag split by an earlier removal cannot survive.
  let text = md.replace(/^---[\s\S]*?---\s*/, "").replace(/<iframe\b[\s\S]*?<\/iframe\s*>/gi, "")
  for (let before = ""; before !== text;) { before = text; text = text.replace(/<\/?iframe\b[^>]*>?/gi, "") }
  return text
    .replace(/^\s*#\s+.*\n/, "")
    .replace(/\*\*(Implementation Effort|User Impact):\*\*.*\n/g, "")
    .trim()
}
