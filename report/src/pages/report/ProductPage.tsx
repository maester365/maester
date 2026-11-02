// One product: its pass rate, its features, and its tests.

import { useState } from "react"
import { tally, type Row } from "@/lib/model"
import { useReport } from "@/components/report/ReportContext"
import { Footer, TestTable } from "@/components/report/lists"
import { Bar, FeatureMark, ProductMark } from "@/components/report/ui"

export function Segmented({ options, value, onChange, label }: { options: [string, string][]; value: string; onChange: (v: string) => void; label: string }) {
  return (
    <div className="mt-seg" role="group" aria-label={label}>
      {options.map(([v, l]) => <button key={v} type="button" aria-pressed={value === v} onClick={() => onChange(v)}>{l}</button>)}
    </div>
  )
}

export default function ProductPage({ productKey }: { productKey: string }) {
  const { model, openTest, explore } = useReport()
  const [group, setGroup] = useState(model.hasAttributes ? "feature" : "none")
  const product = model.products.find((p) => p.key === productKey)
  if (!product) return <div className="mt-wrap"><h1 className="mt-h1">No tests for this product</h1></div>
  const c = tally(product.rows)
  const features = new Map<string, Row[]>()
  for (const t of product.rows) { const k = t.Feature || ""; if (!features.has(k)) features.set(k, []); features.get(k)!.push(t) }
  const related = model.rows.filter((t) => t.RelatedProduct.includes(productKey))
  return (
    <div className="mt-wrap">
      <div className="mt-headrow">
        <div style={{ display: "flex", gap: 14, alignItems: "center" }}><ProductMark product={product.key} size="lg" /><div className="mt-head"><div className="mt-eyebrow">Product</div><h1 className="mt-h1">{product.name}</h1></div></div>
        <div className="mt-legend" style={{ fontSize: 13 }}><span><b className="mt-num">{c.rate ?? "–"}{c.rate !== null ? "%" : ""}</b>&nbsp;passed</span><span><b className="mt-num">{c.Failed}</b>&nbsp;failed</span><span><b className="mt-num">{c.total}</b>&nbsp;tests</span></div>
      </div>
      <Bar tally={c} />
      {model.hasAttributes && features.size > 1 && (
        <section className="mt-sec">
          <h2 className="mt-h2">By feature</h2>
          <div className="mt-tiles">
            {[...features.entries()].sort((a, b) => tally(b[1]).Failed - tally(a[1]).Failed).map(([k, rows]) => {
              const fc = tally(rows)
              const name = k ? model.featureName(rows[0]) : "Other"
              const open = () => explore({ filters: k ? { Product: [product.key], Feature: [`${product.key}/${k}`] } : { Product: [product.key] } })
              return (
                <button key={k} type="button" className="mt-tile" onClick={open}>
                  <span className="mt-ftitle"><FeatureMark product={product.key} feature={k || null} /><b>{name.charAt(0).toUpperCase() + name.slice(1)}</b></span>
                  <Bar tally={fc} thin /><span className="f"><span>{fc.Failed} failed of {fc.total}</span><span className="mt-num">{fc.rate === null ? "–" : `${fc.rate}%`}</span></span>
                </button>
              )
            })}
          </div>
        </section>
      )}
      {related.length > 0 && <p className="mt-callout">{related.length === 1 ? "1 test of another product also touches" : `${related.length} tests of other products also touch`} {product.name}{related.length === 1 ? ":" : ", for example"}&nbsp;<a href={`#${related[0].Id}`} className="mt-link" onClick={(e) => { e.preventDefault(); openTest(related[0].Id) }}>{related[0].Title}</a>.</p>}
      <section className="mt-sec">
        <div className="mt-sechead"><h2 className="mt-h2">Tests</h2><Segmented label="Group tests" value={group} onChange={setGroup} options={[...(model.hasAttributes ? [["feature", "Feature"], ["area", "Area"]] as [string, string][] : []), ["source", "Source"], ["none", "None"]]} /></div>
        <TestTable rows={product.rows} group={group} />
      </section>
      <Footer />
    </div>
  )
}
