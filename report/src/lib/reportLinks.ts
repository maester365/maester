type ReportLocation = {
  pathname: string
  hash: string
}

const knownReportPaths = new Set(["", "settings", "system", "config"])
export const reportMainElementId = "report-main"

function safeDecodeURIComponent(value: string) {
  try {
    return decodeURIComponent(value)
  } catch {
    return value
  }
}

export function getTestResultAnchorId(testResult: { Id?: unknown } | null | undefined) {
  const id = typeof testResult?.Id === "string" ? testResult.Id.trim() : ""
  // HTML id values must not contain whitespace; replace any interior spaces so
  // getElementById and URL fragments remain reliable for non-standard test IDs.
  return id ? id.replace(/\s+/g, "-") : undefined
}

export function getTestResultAnchorHash(anchorId: string) {
  return `#${encodeURIComponent(anchorId)}`
}

export function getLinkedTestResultId(location: ReportLocation) {
  if (location.hash.length > 1) {
    return safeDecodeURIComponent(location.hash.slice(1))
  }

  const path = location.pathname.replace(/^\/+/, "")

  if (!path || knownReportPaths.has(path) || path.startsWith("view/")) {
    return undefined
  }

  return safeDecodeURIComponent(path)
}

export function scrollReportToTop() {
  document.getElementById(reportMainElementId)?.scrollTo({
    top: 0,
    behavior: "smooth",
  })
}
