interface SortableTestResult {
  Id?: string
  Name?: string
  Result?: string
  Severity?: string
}

const severityOrder: Record<string, number> = {
  High: 0,
  Medium: 1,
  Low: 2,
  Critical: 3,
  Info: 4,
}

const statusOrder: Record<string, number> = {
  Failed: 0,
  Investigate: 1,
  Error: 2,
  Passed: 3,
  Skipped: 4,
  NotRun: 5,
}

const getRank = (value: string | undefined, order: Record<string, number>) =>
  value === undefined ? Number.MAX_SAFE_INTEGER : order[value] ?? Number.MAX_SAFE_INTEGER

export function compareDefaultTestResults(a: SortableTestResult, b: SortableTestResult) {
  const severityDifference =
    getRank(a.Severity, severityOrder) - getRank(b.Severity, severityOrder)

  if (severityDifference !== 0) {
    return severityDifference
  }

  const statusDifference =
    getRank(a.Result, statusOrder) - getRank(b.Result, statusOrder)

  if (statusDifference !== 0) {
    return statusDifference
  }

  return (a.Id || a.Name || "").localeCompare(b.Id || b.Name || "")
}
