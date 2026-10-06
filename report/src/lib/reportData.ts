const reportDataElementId = "maester-report-data"

export async function loadReportData(): Promise<unknown> {
  const embedded = document.getElementById(reportDataElementId)?.textContent?.trim()

  if (import.meta.env.DEV) {
    const { testResults } = await import("@/lib/testResults")
    const { applyDevSample } = await import("@/lib/devSampleSchema21")
    return applyDevSample(testResults, new URLSearchParams(window.location.search).get("sample"))
  }

  if (!embedded) {
    throw new Error("Report data was not embedded in the generated HTML file")
  }

  const json = embedded.replace(/^(?:const|let|var)\s+\w+\s*=\s*/, "")
  return JSON.parse(json) as unknown
}
