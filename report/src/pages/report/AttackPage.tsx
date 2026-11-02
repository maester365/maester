// The ATT&CK techniques the tests help defend against, by tactic, coloured by how their tests did.

import { TACTICS, tally, type Row } from "@/lib/model"
import { useReport } from "@/components/report/ReportContext"
import { Footer } from "@/components/report/lists"

export default function AttackPage() {
  const { model, explore } = useReport()
  const byTechnique = new Map<string, Row[]>()
  for (const t of model.rows) for (const m of t.Mitre) { if (!byTechnique.has(m)) byTechnique.set(m, []); byTechnique.get(m)!.push(t) }
  const state = (rows: Row[]) => { const c = tally(rows); return c.Failed && !c.Passed ? "fail" : c.Failed ? "part" : c.Passed ? "pass" : "none" }
  const columns = TACTICS.map(([id, name]) => ({ id, name, techniques: [...byTechnique.keys()].filter((k) => model.technique(k).Tactics.includes(id)).sort((a, b) => tally(byTechnique.get(b)!).Failed - tally(byTechnique.get(a)!).Failed) })).filter((c) => c.techniques.length)
  const failing = [...byTechnique.values()].filter((rows) => tally(rows).Failed).length
  return (
    <div className="mt-wrap">
      <div className="mt-head">
        <div className="mt-eyebrow">Threats{model.attackVersion ? ` · ATT&CK ${model.attackVersion}` : ""}</div>
        <h1 className="mt-h1">{failing} of {byTechnique.size} techniques have a failing defence</h1>
        <p className="mt-lead">Each tile is a technique a Maester test helps defend against. Red means every test for it failed, amber means some did. Choose a tile to list its tests.</p>
      </div>
      <div className="mt-legend"><span><i style={{ background: "var(--mt-fail)" }} />All tests failed</span><span><i style={{ background: "var(--mt-warn)" }} />Some failed</span><span><i style={{ background: "var(--mt-pass)" }} />All passed</span><span><i style={{ background: "var(--mt-skip)" }} />Not run</span></div>
      <div className="mt-attack">
        {columns.map((col) => (
          <div key={col.id} className="mt-tac">
            <h6>{col.name}<span>{col.id} · {col.techniques.length}</span></h6>
            {col.techniques.map((k) => {
              const rows = byTechnique.get(k)!
              return (
                <button key={k} type="button" className={`mt-tech ${state(rows)}`} title={`${rows.length} tests`} onClick={() => explore({ q: k })}>
                  <span className="id">{k} · {tally(rows).Failed}/{rows.length}</span>{model.technique(k).Name}
                </button>
              )
            })}
          </div>
        ))}
      </div>
      <Footer />
    </div>
  )
}
