// What changed since the previous run on this tenant (the result's Previous field).

import { useReport } from "@/components/report/ReportContext"
import { Footer, TestTable } from "@/components/report/lists"
import { formatDate } from "@/components/report/ui"

export default function ChangesPage() {
  const { model } = useReport()
  const { previous, changes } = model
  if (!previous) return <div className="mt-wrap"><h1 className="mt-h1">No earlier result</h1><p className="mt-lead">Maester found no earlier result for this tenant in the output folder.</p></div>
  return (
    <div className="mt-wrap">
      <div className="mt-head">
        <div className="mt-eyebrow">Compared with {formatDate(previous.ExecutedAt, true)}</div>
        <h1 className="mt-h1">{changes.newlyFailing.length} new failures, {changes.fixed.length} fixed</h1>
        <p className="mt-lead">Maester read {previous.File || "the previous result"} from the output folder. Tests that ran only this time are listed as added.</p>
      </div>
      <section className="mt-sec"><h2 className="mt-h2">Newly failing</h2><TestTable rows={changes.newlyFailing} empty="Nothing that passed last time fails now." /></section>
      <section className="mt-sec"><h2 className="mt-h2">Fixed</h2><TestTable rows={changes.fixed} empty="Nothing that failed last time passes now." /></section>
      {changes.added.length > 0 && <section className="mt-sec"><h2 className="mt-h2">Added this run</h2><TestTable rows={changes.added} /></section>}
      <Footer />
    </div>
  )
}
