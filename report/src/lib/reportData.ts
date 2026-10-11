const reportDataElementId = "maester-report-data"

export async function loadReportData(): Promise<unknown> {
  const embedded = document.getElementById(reportDataElementId)?.textContent?.trim()

  if (import.meta.env.DEV) {
    // ?sample=2x loads a Maester 2.x result, to check that the report still renders one as before.
    if (new URLSearchParams(window.location.search).get("sample") === "2x") {
      return (await import("@/lib/testResultsLegacy")).testResults
    }
    return (await import("@/lib/testResults")).testResults
  }

  if (!embedded) {
    throw new Error("Report data was not embedded in the generated HTML file")
  }

  const json = embedded.replace(/^(?:const|let|var)\s+\w+\s*=\s*/, "")
  return JSON.parse(json) as unknown
}
