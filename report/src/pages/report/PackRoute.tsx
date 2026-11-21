// A page of a pack's menu (components/report/nav.ts): the overview, a list of its tests, a plan, a page of its
// guide or About. The link names the pack and the page; the menu says what the page shows.

import { useState, type ReactNode } from "react"
import { Link, useLocation } from "@/lib/router"
import { tally, type Pack, type Row } from "@/lib/model"
import { fieldValues, type GuideStep } from "@/lib/packNav"
import { useReport } from "@/components/report/ReportContext"
import { useNav } from "@/components/report/Sidebar"
import { packPage, packSlug, type PackPageDef } from "@/components/report/nav"
import { Footer, TestTable } from "@/components/report/lists"
import { Bar, Cmd, Legend } from "@/components/report/ui"
import { Segmented } from "./ProductPage"
import PackPage from "./PackPage"
import ZeroTrustPage from "./ZeroTrustPage"

type PackRows = Pack & { rows: Row[] }

export default function PackRoute() {
  const { model } = useReport()
  const { nav } = useNav()
  const { pathname } = useLocation()
  const { pack, page } = packPage(model, nav, pathname)
  if (!pack) return <div className="mt-wrap"><h1 className="mt-h1">This pack is not in the run</h1><p className="mt-lead"><Link className="mt-link" to="/">Back to the overview</Link></p></div>
  if (!page) return <div className="mt-wrap"><h1 className="mt-h1">This page is not in the pack's menu</h1><p className="mt-lead">The link may be from a report of another version of the pack. <Link className="mt-link" to={`/pack/${encodeURIComponent(packSlug(pack))}`}>Open {pack.Name}</Link></p></div>
  switch (page.view) {
    case "tests": return <TestsView key={pathname} pack={pack} page={page} />
    case "plan": return <ZeroTrustPage key={page.planPath} name={page.attachment} base={page.planPath!} pillarId={page.pillar} areaId={page.area} lane={page.lane} />
    case "guide": return <GuideView pack={pack} page={page} />
    case "about": return <AboutView pack={pack} />
    default: return <PackPage packId={pack.Id} />
  }
}

function Head({ pack, title, lead, children }: { pack: PackRows; title: string; lead?: ReactNode; children?: ReactNode }) {
  return (
    <div className="mt-head">
      <div className="mt-eyebrow">Pack · {pack.Name}</div>
      <h1 className="mt-h1">{title}</h1>
      {lead && <p className="mt-lead">{lead}</p>}
      {children}
    </div>
  )
}

function TestsView({ pack, page }: { pack: PackRows; page: PackPageDef }) {
  const filter = page.filter || {}
  const rows = pack.rows.filter((t) => (!page.result || t.Result === page.result) && Object.entries(filter).every(([k, vs]) => fieldValues(t.Fields || undefined, k).some((v) => vs.includes(v))))
  const fieldKeys = [...new Set(pack.rows.flatMap((t) => Object.keys(t.Fields || {})))]
  const [group, setGroup] = useState(page.groupBy?.[0] || (Object.keys(filter).length ? "none" : fieldKeys[0] || "none"))
  const c = tally(rows)
  const where = Object.entries(filter).map(([k, vs]) => `${k.toLowerCase()} ${vs.join(" or ")}`)
  const lead = `${rows.length} of the pack's ${pack.rows.length} results${page.result ? `, ${page.result === "Failed" ? "that failed" : `with the result ${page.result}`}` : ""}${where.length ? `, ${where.join(", ")}` : ""}.`
  return (
    <div className="mt-wrap">
      <Head pack={pack} title={page.title} lead={lead} />
      {rows.length > 0 && <div><Bar tally={c} /><Legend tally={c} /></div>}
      <section className="mt-sec">
        <div className="mt-sechead"><h2 className="mt-h2">Results</h2>
          <Segmented label="Group tests" value={group} onChange={setGroup} options={[...fieldKeys.map((k) => [k, k] as [string, string]), ["result", "Result"], ["none", "None"]]} />
        </div>
        <TestTable rows={rows} group={group} empty="No results of the pack match this page." />
      </section>
      <Footer />
    </div>
  )
}

const Steps = ({ steps }: { steps?: GuideStep[] }) => (steps?.length ? (
  <ol className="mt-guide-steps">{steps.map((s, i) => <li key={i}>{s.Text && <p>{s.Text}</p>}{s.Command && <Cmd command={s.Command} wrap />}</li>)}</ol>
) : null)
const Notes = ({ notes }: { notes?: string[] }) => (notes?.length ? <ul className="mt-guide-notes">{notes.map((n, i) => <li key={i}>{n}</li>)}</ul> : null)
const More = ({ url }: { url?: string }) => (url && /^https:\/\//i.test(url) ? <p><a className="mt-link" href={url} target="_blank" rel="noopener noreferrer">More in the pack's documentation ↗</a></p> : null)

function GuideView({ pack, page }: { pack: PackRows; page: PackPageDef }) {
  const g = pack.Guide
  if (!g) return <div className="mt-wrap"><Head pack={pack} title={page.title} lead="The pack has no guide." /></div>
  let body: ReactNode
  if (page.page === "connect") {
    body = <>
      <section className="mt-sec"><h2 className="mt-h2">Connect</h2><Steps steps={g.Connect?.Steps} /><Notes notes={g.Connect?.Notes} /><More url={g.Connect?.More} /></section>
      {g.AppOnly && <section className="mt-sec"><h2 className="mt-h2">Run without a person signed in</h2>
        <p>{g.AppOnly.Supported === false ? "The pack does not support app-only sign-in." : g.AppOnly.Text}</p>
        {g.AppOnly.Command && <Cmd command={g.AppOnly.Command} wrap />}<More url={g.AppOnly.More} /></section>}
    </>
  } else if (page.page === "run") {
    body = <>
      <section className="mt-sec"><h2 className="mt-h2">Run</h2><Steps steps={g.Run?.Commands} /><Notes notes={g.Run?.Notes} /></section>
      {!!g.Run?.Options?.length && <section className="mt-sec"><h2 className="mt-h2">Settings</h2>
        <div className="mt-card"><table className="mt-table"><thead><tr><th>Setting</th><th>Default</th><th>What it does</th></tr></thead>
          <tbody>{g.Run.Options.map((o) => <tr key={o.Name}><td className="mt-mono">{o.Name}</td><td className="mt-mono">{o.Default ?? "–"}</td><td>{o.Text}</td></tr>)}</tbody></table></div>
        <More url={g.Run.More} /></section>}
    </>
  } else {
    body = <>
      {!!g.Prerequisites?.length && <section className="mt-sec"><h2 className="mt-h2">Before you start</h2><Steps steps={g.Prerequisites} /></section>}
      {!!g.Links?.length && <section className="mt-sec"><h2 className="mt-h2">Links</h2><ul className="mt-guide-notes">{g.Links.filter((l) => /^https:\/\//i.test(l.Url)).map((l) => <li key={l.Url}><a className="mt-link" href={l.Url} target="_blank" rel="noopener noreferrer">{l.Text} ↗</a></li>)}</ul></section>}
    </>
  }
  return (
    <div className="mt-wrap mt-guide">
      <Head pack={pack} title={page.title} lead={page.page === "start" || !page.page ? g.Summary : undefined} />
      {body}
      <Footer />
    </div>
  )
}

function AboutView({ pack }: { pack: PackRows }) {
  const { model } = useReport()
  const rows: [string, ReactNode][] = [
    ["Pack", <span className="mt-mono">{pack.Id}</span>],
    ["Code", <span className="mt-code">{pack.Code}</span>],
    ["Version", pack.Version || "–"],
    ["Publisher", pack.Publisher || "–"],
    ["Source", pack.BuiltIn ? "Ships with Maester" : "Installed pack"],
    ["Risk accepted at install", pack.Risk || (pack.BuiltIn ? "Not needed" : "–")],
    ["Status in this run", pack.Status === "Ready" ? "Ran" : `${pack.Status}${pack.Reason ? `: ${pack.Reason}` : ""}`],
    ["Results", `${pack.rows.length}, of ${model.rows.length} in the run`],
  ]
  return (
    <div className="mt-wrap">
      <Head pack={pack} title="About this pack" lead={pack.Description || undefined} />
      <dl className="mt-kv flat">{rows.map(([k, v]) => [<dt key={`k${k}`}>{k}</dt>, <dd key={`v${k}`}>{v}</dd>])}</dl>
      {pack.Homepage && /^https:\/\//i.test(pack.Homepage) && <p><a className="mt-link" href={pack.Homepage} target="_blank" rel="noopener noreferrer">The pack's page ↗</a></p>}
      <p className="mt-note">A pack's results count in this report, but never as Maester's own checks. Its menu is drawn by the report from the pack's manifest; a pack adds no code to this page.</p>
      <Footer />
    </div>
  )
}
