// How the report was made: the run, the connections, the suites and packs, and links to the system and config pages.

import { Link } from "@/lib/router"
import { maesterVersion } from "@/lib/model"
import { useReport } from "@/components/report/ReportContext"
import { Footer } from "@/components/report/lists"
import { Cmd, formatDate, plural } from "@/components/report/ui"

export default function RunPage() {
  const { model } = useReport()
  const r = model.result
  const version = maesterVersion(r)
  const sources = new Map<string, number>()
  for (const t of model.rows) { const k = model.packOf(t)?.Name || t.Suite || t.Source || "Other"; sources.set(k, (sources.get(k) || 0) + 1) }
  const connections: { Service: string; Status: string; Details?: string }[] = Array.isArray(r.ConnectionSummary) ? r.ConnectionSummary : []
  const files = r.OutputFiles ? Object.entries(r.OutputFiles).filter(([k, v]) => v && k !== "OutputFolder" && k !== "OutputFolderFileName") : []
  const runRows: [string, unknown][] = [
    ["Started", r.ExecutedAt ? formatDate(r.ExecutedAt, true) : null], ["Duration", r.TotalDuration],
    ["Maester", version ? `${version}${r.LatestVersion && String(r.LatestVersion) !== version ? ` (${r.LatestVersion} available)` : ""}` : null],
    ["Account", r.Account], ["Tenant ID", r.TenantId], ["Dry run", r.Selection?.DryRun ? "Yes" : null],
  ]
  return (
    <div className="mt-wrap">
      <div className="mt-head"><div className="mt-eyebrow">Run details</div><h1 className="mt-h1">How this report was made</h1></div>
      <div className="mt-grid mt-g2">
        <div className="mt-card mt-pad mt-sec">
          <h2 className="mt-h2">Run</h2>
          <dl className="mt-kv">{runRows.filter(([, v]) => v).map(([k, v]) => <div key={k}><dt>{k}</dt><dd className={k === "Tenant ID" ? "mt-mono" : ""} style={k === "Tenant ID" ? { fontSize: 11.5 } : undefined}>{String(v)}</dd></div>)}</dl>
          {r.InvokeCommand && <Cmd command={String(r.InvokeCommand)} wrap />}
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}><Link className="mt-btn" to="/system">System and modules</Link><Link className="mt-btn" to="/config">Maester config</Link></div>
        </div>
        {connections.length > 0 && (
          <div className="mt-card mt-pad mt-sec">
            <h2 className="mt-h2">Connections</h2>
            <div className="mt-links">{connections.map((c) => <div key={c.Service}><span>{c.Service}{c.Details && c.Status !== "Connected" ? <span className="mt-muted" style={{ display: "block", fontSize: 12, fontFamily: "var(--mt-font)" }}>{c.Details}</span> : null}</span><span className={`mt-pill ${c.Status === "Connected" ? "mt-r-Passed" : "mt-r-Skipped"}`} style={{ fontFamily: "var(--mt-font)" }}>{c.Status}</span></div>)}</div>
          </div>
        )}
        <div className="mt-card mt-pad mt-sec">
          <h2 className="mt-h2">Suites and packs</h2>
          <div className="mt-links">{[...sources.entries()].sort((a, b) => b[1] - a[1]).map(([k, n]) => <div key={k}><span>{k}</span><span>{plural(n, "test")}</span></div>)}</div>
        </div>
        {files.length > 0 && (
          <div className="mt-card mt-pad mt-sec">
            <h2 className="mt-h2">Files written</h2>
            <div className="mt-links">{files.map(([k, v]) => <div key={k}><span className="mt-mono" style={{ fontSize: 12, overflowWrap: "anywhere" }}>{String(v)}</span><span /></div>)}</div>
          </div>
        )}
      </div>
      <Footer />
    </div>
  )
}
