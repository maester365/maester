const reportDataElementId = "maester-report-data"

export async function loadReportData(): Promise<unknown> {
  const embedded = document.getElementById(reportDataElementId)?.textContent?.trim()

  if (import.meta.env.DEV) {
    // ?sample=2x loads a Maester 2.x result, to check that the report still renders one.
    const sample = new URLSearchParams(window.location.search).get("sample")
    if (sample === "2x") {
      return (await import("@/lib/testResultsLegacy")).testResults
    }
    const results = (await import("@/lib/testResults")).testResults
    const { withSampleExtras } = await import("@/lib/sampleExtras")
    // ?sample=tenants shows a merged report of five tenants.
    if (sample === "tenants") {
      const merged = (await import("@/lib/sampleTenants")).sampleTenants(results)
      return { Tenants: merged.Tenants.map((t: Record<string, unknown>, i: number) => withSampleExtras(t, i)) }
    }
    // ?sample=one and ?sample=suite show how the report looks for a run of one test or of the CIS suite.
    if (sample === "one" || sample === "suite") {
      const tests = results.Tests.filter((t) => (sample === "one" ? t.Id === "CIS.M365.1.1.1" : t.Suite === "CIS"))
      return { ...results, Tests: tests, Packs: [], InvokeCommand: sample === "one" ? "Invoke-Maester -TestId CIS.M365.1.1.1" : "Invoke-Maester -Suite CIS" }
    }
    return withSampleExtras(results)
  }

  if (!embedded) {
    throw new Error("Report data was not embedded in the generated HTML file")
  }

  const json = embedded.replace(/^(?:const|let|var)\s+\w+\s*=\s*/, "")
  return JSON.parse(json) as unknown
}
