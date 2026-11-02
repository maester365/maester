// One framework, counted by requirement: met when every test for it passes, not met when one fails, and
// "no Maester test" for a requirement of the catalogue that no test checks.

import { useState } from "react"
import { frameworkLabel, frameworkTally, requirementStatus } from "@/lib/model"
import { useReport } from "@/components/report/ReportContext"
import { Footer } from "@/components/report/lists"
import { Bar, Pill } from "@/components/report/ui"
import { Segmented } from "./ProductPage"

const CIS_SECTIONS: Record<string, string> = { 1: "Microsoft 365 admin center", 2: "Microsoft 365 Defender", 3: "Microsoft Purview", 4: "Microsoft Intune", 5: "Microsoft Entra admin center", 6: "Exchange admin center", 7: "SharePoint admin center", 8: "Microsoft Teams admin center", 9: "Microsoft Fabric" }
const CISA_SERVICES: Record<string, string> = { "MS.AAD": "Entra ID", "MS.DEFENDER": "Defender", "MS.EXO": "Exchange Online", "MS.POWERBI": "Power BI", "MS.POWERPLATFORM": "Power Platform", "MS.SHAREPOINT": "SharePoint", "MS.TEAMS": "Teams", "MS.SECURITYSUITE": "Security suite" }

// The framework's own structure: CIS sections, CISA services, Essential Eight strategies, ISM guidelines, NIST families.
function sectionOf(key: string, r: Record<string, unknown>): string {
  const id = String(r.Id)
  if (key.startsWith("cis-")) { const s = id.split(".")[0]; return CIS_SECTIONS[s] ? `${s} · ${CIS_SECTIONS[s]}` : s }
  if (key === "cisa-scuba") { const s = id.split(".").slice(0, 2).join("."); return CISA_SERVICES[s] ? `${s} · ${CISA_SERVICES[s]}` : s }
  if (key === "essential-eight") return (Array.isArray(r.Strategy) ? r.Strategy[0] : r.Strategy) as string || "Other"
  if (key === "ism") return (r.Guideline as string) || "Other"
  if (key.startsWith("nist")) return (r.Family as string) || id.split("-")[0]
  return "Requirements"
}

export default function FrameworkPage({ frameworkKey }: { frameworkKey: string }) {
  const { model, openTest } = useReport()
  const [level, setLevel] = useState("All")
  const [show, setShow] = useState("all")
  const f = model.frameworks.find((x) => x.Key === frameworkKey)
  if (!f) return <div className="mt-wrap"><h1 className="mt-h1">No tests map to this framework</h1></div>
  const levels = ["All", ...new Set(f.Requirements.map((r) => String(r.Level || r.Criticality || "")).filter(Boolean))].sort((a, b) => (a === "All" ? -1 : b === "All" ? 1 : a.localeCompare(b)))
  const requirements = f.Requirements.filter((r) => level === "All" || r.Level === level || r.Criticality === level)
  const c = frameworkTally(model, f, requirements)
  const sections = new Map<string, typeof requirements>()
  for (const r of requirements) { const s = sectionOf(f.Key, r); if (!sections.has(s)) sections.set(s, []); sections.get(s)!.push(r) }

  return (
    <div className="mt-wrap">
      <div className="mt-head">
        <div className="mt-eyebrow">Framework{f.Version ? ` · v${f.Version}` : ""}</div>
        <h1 className="mt-h1">{f.Name || frameworkLabel(f)}</h1>
        <p className="mt-lead">{f.Complete ? `${c.total - c.none} of ${c.total} requirements have a Maester test. ${c.Failed} are not met.` : `${c.total} requirements are mapped to the tests of this run. Requirements with no test are not listed.`}</p>
      </div>
      <div className="mt-grid mt-g4">
        {([["Met", c.Passed, "Passed"], ["Not met", c.Failed, "Failed"], ["Not run or to investigate", c.Skipped + c.Investigate, "Skipped"], ...(f.Complete ? [["No Maester test", c.none, "none"]] : [])] as [string, number, string][]).map(([label, n, r]) => (
          <div key={label} className="mt-card mt-pad" style={{ padding: "14px 16px" }}><div className="mt-legend"><span><i className={`mt-b-${r}`} />{label}</span></div><b className="mt-num" style={{ fontSize: 26, letterSpacing: "-.02em" }}>{n}</b></div>
        ))}
      </div>
      <div className="mt-toolbar">
        {levels.length > 2 && <Segmented label="Level" value={level} onChange={setLevel} options={levels.map((l) => [l, l === "All" ? "All levels" : l])} />}
        <Segmented label="Show" value={show} onChange={setShow} options={[["all", "All"], ["Failed", "Not met"], ...(f.Complete ? [["none", "No test"]] as [string, string][] : [])]} />
      </div>
      <div className="mt-sec">
        {[...sections.entries()].map(([section, reqs]) => {
          const items = reqs.map((r) => ({ r, tests: model.requirementTests(f.Key, String(r.Id)) })).filter((x) => show === "all" || requirementStatus(x.tests) === show)
          if (!items.length) return null
          const sc = frameworkTally(model, f, reqs)
          return (
            <details key={section} className="mt-reqgroup" open={sc.Failed > 0 || show !== "all"}>
              <summary><b>{section}</b><Bar thin tally={{ total: sc.total, Passed: sc.Passed, Failed: sc.Failed, Investigate: sc.Investigate, Skipped: sc.Skipped }} /><span className="mt-mono mt-muted" style={{ fontSize: 12 }}>{sc.Failed} not met · {sc.total}</span></summary>
              {items.map(({ r, tests }) => {
                const status = requirementStatus(tests)
                const content = (
                  <>
                    <span className="rid">{String(r.Id)}{r.Level ? <span className="mt-chip mt-mono">{String(r.Level)}</span> : null}{r.Criticality ? <span className="mt-chip mt-mono">{String(r.Criticality)}</span> : null}</span>
                    <span className="tests">{tests.length ? tests.map((t) => <span key={t.Id}>{t.Title} <span className="mt-mono mt-muted" style={{ fontSize: 11 }}>{t.Id}</span></span>) : <span className="mt-gap">{r.Title ? String(r.Title) : "No Maester test yet"}</span>}</span>
                    <Pill result={status} />
                  </>
                )
                return tests.length ? <button key={String(r.Id)} type="button" className="mt-req" onClick={() => openTest(tests[0].Id)}>{content}</button> : <div key={String(r.Id)} className="mt-req">{content}</div>
              })}
            </details>
          )
        })}
      </div>
      <Footer />
    </div>
  )
}
