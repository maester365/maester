// One Maester Pack: who publishes it, how its tests did, its own grouping (from the Fields its rows carry, such
// as the Zero Trust Assessment's pillars), and the report it embedded, if any.

import { useState } from "react"
import { Link } from "@/lib/router"
import { getAttachmentPath, getTestAttachments } from "@/lib/reportAttachments"
import { tally, type Row } from "@/lib/model"
import { useReport } from "@/components/report/ReportContext"
import { Footer, TestTable } from "@/components/report/lists"
import { Bar, Legend } from "@/components/report/ui"
import { Segmented } from "./ProductPage"

export default function PackPage({ packId }: { packId: string }) {
  const { model } = useReport()
  const pack = model.packs.find((p) => p.Id === packId)
  const fieldKeys = pack ? [...new Set(pack.rows.flatMap((t) => Object.keys(t.Fields || {})))] : []
  const [group, setGroup] = useState(fieldKeys[0] || "area")
  if (!pack) return <div className="mt-wrap"><h1 className="mt-h1">This pack is not in the run</h1></div>
  const c = tally(pack.rows)
  const attachments = [...new Map(pack.rows.flatMap((t) => getTestAttachments(model.result, { Id: t.Id, ParentId: t.ParentId })).map((a) => [a.Id, a])).values()]
  const first = fieldKeys[0]
  const cards = new Map<string, Row[]>()
  if (first) for (const t of pack.rows) {
    const value = t.Fields?.[first]
    for (const v of (Array.isArray(value) ? value : value ? [value] : ["Other"])) { if (!cards.has(v)) cards.set(v, []); cards.get(v)!.push(t) }
  }
  return (
    <div className="mt-wrap">
      <div className="mt-headrow">
        <div style={{ display: "flex", gap: 14, alignItems: "center" }}>
          <span className="mt-code lg">{pack.Code}</span>
          <div className="mt-head"><div className="mt-eyebrow">Pack · {pack.Id}{pack.Version ? ` · v${pack.Version}` : ""}</div><h1 className="mt-h1">{pack.Name}</h1></div>
        </div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          {pack.BuiltIn && <span className="mt-chip ember">Official</span>}
          {pack.Risk && <span className="mt-chip">{pack.Risk} risk</span>}
          {pack.Publisher && <span className="mt-chip">by {pack.Publisher}</span>}
          {pack.Homepage && /^https:\/\//i.test(pack.Homepage) && <a className="mt-chip" href={pack.Homepage} target="_blank" rel="noopener noreferrer">Pack page ↗</a>}
        </div>
      </div>
      <p className="mt-lead">{pack.Description ? `${pack.Description} ` : ""}Its results count in this report, but never as Maester's own checks.</p>
      {pack.Status !== "Ready" && <div className="mt-callout warn"><span><b>The pack did not run.</b> {pack.Reason}</span></div>}
      {pack.rows.length > 0 && <><Bar tally={c} /><Legend tally={c} /></>}
      {attachments.map((a) => (
        <Link key={a.Id} to={getAttachmentPath(a)} className="mt-card mt-pad" style={{ display: "flex", gap: 14, alignItems: "center", justifyContent: "space-between", flexWrap: "wrap" }}>
          <span><b>{a.Name} report</b><br /><span className="mt-muted" style={{ fontSize: 13 }}>The pack embedded its own report in this file. Open it to see the results as the tool presents them.</span></span>
          <span className="mt-btn">Open report</span>
        </Link>
      ))}
      {cards.size > 1 && (
        <section className="mt-sec">
          <h2 className="mt-h2">By {first.toLowerCase()}</h2>
          <div className="mt-tiles">
            {[...cards.entries()].sort((a, b) => b[1].length - a[1].length).map(([k, rows]) => {
              const pc = tally(rows)
              return <div key={k} className="mt-tile"><b>{k}</b><Bar tally={pc} thin /><span className="f"><span>{pc.Failed} failed of {pc.total}</span><span className="mt-num">{pc.rate === null ? "–" : `${pc.rate}%`}</span></span></div>
            })}
          </div>
        </section>
      )}
      <section className="mt-sec">
        <div className="mt-sechead"><h2 className="mt-h2">Results</h2>
          <Segmented label="Group tests" value={group} onChange={setGroup} options={[...fieldKeys.map((k) => [k, k] as [string, string]), ["area", "Area"], ["result", "Result"], ["none", "None"]]} />
        </div>
        <TestTable rows={pack.rows} group={group} empty="The pack produced no results." />
      </section>
      <Footer />
    </div>
  )
}
