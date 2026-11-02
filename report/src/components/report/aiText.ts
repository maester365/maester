// Text a reader copies into an AI assistant or a ticket: one test, the whole run, every failure, or a CSV.

import { RESULT_LABEL, RESULTS, frameworkLabel, frameworkTally, maesterVersion, requirementsOf, type Model, type Row } from "@/lib/model"
import { crossTests, failingInMost, failingInOne, tenantName } from "@/lib/tenants"

export function testAsMarkdown(model: Model, t: Row) {
  return [
    `## ${t.Id}: ${t.Title}`,
    "",
    `- Result: ${RESULT_LABEL[t.Result] || t.Result}`,
    `- Severity: ${t.Severity || "not set"}`,
    t.Product ? `- Product: ${model.productName(t.Product)}` : "",
    t.UserImpact || t.ImplementationCost ? `- User impact: ${t.UserImpact || "?"}, effort to fix: ${t.ImplementationCost || "?"}` : "",
    `- Frameworks: ${requirementsOf(t).map(([k, id]) => `${k} ${id}`).join(", ") || "none"}`,
    `- ATT&CK: ${t.Mitre.join(", ") || "none"}`,
    t.ReasonCode ? `- Did not run: ${t.ReasonCode}. ${t.ReasonDetail || ""}` : "",
    "",
    "### What Maester found",
    "",
    t.Detail || "No details.",
    "",
    "### Guidance",
    "",
    t.Description || "",
  ].filter((line, i, all) => line !== "" || all[i - 1] !== "").join("\n")
}

export function summaryMarkdown(model: Model) {
  const r = model.result
  return [
    `# Maester report: ${r.TenantName || r.TenantId || "tenant"}`,
    "",
    `Run ${r.ExecutedAt}, Maester ${maesterVersion(r)}. ${model.all.total} tests: ${RESULTS.map((k) => `${model.all[k]} ${RESULT_LABEL[k].toLowerCase()}`).join(", ")}. Pass rate ${model.all.rate ?? "n/a"}%.`,
    "",
    "## Failures, most important first",
    "",
    ...model.ranked.slice(0, 25).map((t) => `- ${t.Id} (${t.Severity}, ${model.productName(t.Product)}, user impact ${t.UserImpact || "?"}, effort ${t.ImplementationCost || "?"}): ${t.Title}`),
    "",
    "## Frameworks",
    "",
    ...model.frameworks.map((f) => { const c = frameworkTally(model, f); return `- ${frameworkLabel(f)}: ${c.Passed} met, ${c.Failed} not met${f.Complete ? `, ${c.none} without a Maester test` : ""}, of ${c.total} requirements` }),
  ].join("\n")
}

/** Several tenants: how each did, and the failures most of them share. */
export function tenantsMarkdown(models: Model[]) {
  const names = models.map((m, i) => tenantName(m, i))
  const cross = crossTests(models)
  const line = (c: ReturnType<typeof crossTests>[number]) => `- ${c.id} (${c.test.Severity}): ${c.test.Title}. Fails in ${c.results.map((r, i) => (r?.Result === "Failed" ? names[i] : "")).filter(Boolean).join(", ")}.`
  return [
    `# Maester report: ${models.length} tenants`,
    "",
    "| Tenant | Run | Pass rate | Failed | Not run |",
    "| --- | --- | --- | --- | --- |",
    ...models.map((m, i) => `| ${names[i]} | ${String(m.result.ExecutedAt || "").slice(0, 10)} | ${m.all.rate ?? "n/a"}% | ${m.all.Failed} | ${m.all.Skipped + m.all.NotRun + m.all.Error} |`),
    "",
    "## Failing in most tenants",
    "",
    ...failingInMost(cross).slice(0, 30).map(line),
    "",
    "## Failing in one tenant only",
    "",
    ...failingInOne(cross).slice(0, 20).map(line),
  ].join("\n")
}

export const failuresMarkdown = (model: Model) => model.ranked.map((t) => testAsMarkdown(model, t)).join("\n\n---\n\n")

export function failuresCsv(model: Model) {
  // A value a spreadsheet would read as a formula (a title from a custom test or pack can start with =) is kept as text.
  const quote = (v: unknown) => {
    const s = String(v ?? "")
    return `"${(/^[=+\-@\t\r]/.test(s) ? `'${s}` : s).replace(/"/g, '""')}"`
  }
  return ["Id,Title,Severity,Product,UserImpact,Effort,Frameworks"]
    .concat(model.ranked.map((t) => [t.Id, t.Title, t.Severity, model.productName(t.Product), t.UserImpact, t.ImplementationCost, requirementsOf(t).map(([k, id]) => `${k}:${id}`).join(" ")].map(quote).join(",")))
    .join("\n")
}
