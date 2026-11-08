// Dev server only: the Zero Trust plan the pack would attach, built from the pack's own files the way
// packs/zero-trust-assessment/helpers/Get-MtZtaWorkshopPlan.ps1 builds it at run time, so the view can be worked
// on without a run. Never part of a built report.

import type { Workshop, WorkshopCheckRef, WorkshopTask } from "@/lib/zeroTrust"

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Raw = Record<string, any>

const files = import.meta.glob<Raw>("../../../packs/zero-trust-assessment/workshop/*.json", { import: "default" })
const taxonomyFile = import.meta.glob<Raw>("../../../packs/zero-trust-assessment/taxonomy.json", { import: "default" })

const ORDER = ["identity", "devices", "data", "network", "infrastructure", "security-operations", "ai"]

export async function sampleWorkshop(): Promise<Workshop> {
  const loaded: Record<string, Raw> = {}
  for (const [path, load] of Object.entries(files)) loaded[path.split("/").pop()!.replace(/\.json$/, "")] = await load()
  const taxonomy = (await Object.values(taxonomyFile)[0]?.())?.Tests || {}
  const overlay = loaded.maester || { Tasks: {}, ExtraTasks: [] }
  const icons: Record<string, string> = loaded.icons?.Icons || {}
  const used: Record<string, string> = {}
  const useIcon = (n?: string) => { if (n && icons[n]) used[n] = icons[n] }
  const pillars = ORDER.filter((id) => loaded[id]).map((id) => {
    const p = loaded[id]
    const tasks: WorkshopTask[] = (p.Tasks || []).map((t: Raw) => {
      const checks: WorkshopCheckRef[] = []
      for (const z of t.Checks || []) {
        checks.push({ Id: z, Source: "microsoft" })
        for (const m of taxonomy[String(z).replace(/^ZTA\./, "")]?.AlsoCheckedBy || []) checks.push({ Id: m, Source: "same-check", Via: z })
      }
      const extra = overlay.Tasks?.[t.Id]
      for (const m of extra?.Tests || []) checks.push({ Id: m, Source: "maester" })
      useIcon(t.Icon)
      return { ...t, Note: extra?.Note, Origin: "workshop", Checks: checks.filter((c, i) => checks.findIndex((x) => x.Id === c.Id) === i) }
    })
    for (const x of (overlay.ExtraTasks || []).filter((x: Raw) => x.Pillar === id)) {
      tasks.push({ ...x, Origin: "maester", Checks: (x.Tests || []).map((m: string) => ({ Id: m, Source: "maester" })) })
    }
    for (const a of p.Areas || []) useIcon(a.Icon)
    return { Id: p.Id, Name: p.Name, Areas: p.Areas || [], Tasks: tasks }
  })
  const updated = Object.values(loaded).find((f) => f?.Source?.Updated)?.Source?.Updated
  return { Schema: "maester.zero-trust-workshop/1", Source: { Name: "Microsoft Zero Trust Workshop", Url: "https://zerotrust.microsoft.com", Updated: updated }, Pillars: pillars, Icons: used }
}
