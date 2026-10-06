// Helpers for the fields that result schema 2.1 (Maester 3.0) adds. Every 2.1 field is optional:
// results written by Maester 2.x have none of them, so each helper copes with a missing value.

type ReasonColor = "amber" | "gray" | "orange" | "purple" | "red" | "yellow"

interface ReasonInfo {
  label: string
  color: ReasonColor
  description: string
}

// The closed list of reason codes (design appendix A.1). Unknown codes still render, as their raw name.
const reasonCodes: Record<string, ReasonInfo> = {
  // NotRun
  NotSelected: { label: "Not selected", color: "gray", description: "The test matched no include filter." },
  NotListed: { label: "Not listed", color: "gray", description: "The test is not in the list of tests to run." },
  DryRun: { label: "Dry run", color: "gray", description: "Dry run: this test would have run." },
  ExcludedByTag: { label: "Excluded by tag", color: "gray", description: "The test matched an exclude tag." },
  ExcludedById: { label: "Excluded by ID", color: "gray", description: "The test matched an excluded ID." },
  DisabledByConfig: { label: "Disabled by config", color: "gray", description: "The test is disabled in the Maester config." },
  Preview: { label: "Preview", color: "gray", description: "Preview tests run only when the Preview tag is included." },
  LongRunning: { label: "Long running", color: "gray", description: "Long running tests run only when the LongRunning tag is included." },
  OptInServiceNotConnected: { label: "Opt-in service not connected", color: "gray", description: "The test needs an opt-in service that was not connected." },
  DeselectedAtRuntime: { label: "Deselected at runtime", color: "gray", description: "The test was deselected while the run was in progress." },
  // Skipped
  ServiceNotConnected: { label: "Service not connected", color: "yellow", description: "A service the test needs was not connected." },
  ServiceNotRegistered: { label: "Service not registered", color: "yellow", description: "A service the test needs is not registered." },
  LicenseNotFound: { label: "License not found", color: "yellow", description: "The tenant does not have a license the test needs." },
  TenantTypeMismatch: { label: "Tenant type mismatch", color: "yellow", description: "The test does not apply to this tenant type." },
  CloudMismatch: { label: "Cloud mismatch", color: "yellow", description: "The test does not apply to this cloud." },
  PlatformMismatch: { label: "Platform mismatch", color: "yellow", description: "The test does not run on this platform." },
  NotApplicable: { label: "Not applicable", color: "yellow", description: "The test does not apply to this tenant." },
  NoInstances: { label: "No instances", color: "yellow", description: "The test family found nothing to test." },
  NoResult: { label: "No result", color: "yellow", description: "The test returned no result." },
  TestSkipped: { label: "Skipped by test", color: "yellow", description: "The test skipped itself." },
  // Error
  TestError: { label: "Test error", color: "orange", description: "The test threw an error." },
  Timeout: { label: "Timeout", color: "orange", description: "The test ran longer than its timeout." },
  InvalidMetadata: { label: "Invalid metadata", color: "red", description: "The test's metadata is invalid." },
  InvalidConfiguration: { label: "Invalid configuration", color: "red", description: "The test's configuration is invalid." },
  InvalidReturn: { label: "Invalid return", color: "red", description: "The test must return $true or $false." },
  InvalidInstanceId: { label: "Invalid instance ID", color: "red", description: "The family's source returned an invalid instance ID." },
  DuplicateId: { label: "Duplicate ID", color: "red", description: "More than one test uses this ID." },
  LoadFailed: { label: "Load failed", color: "red", description: "The test file could not be parsed or loaded." },
  InstanceSourceFailed: { label: "Instance source failed", color: "red", description: "The family's instance source threw an error." },
  RequiresNewerMaester: { label: "Requires newer Maester", color: "red", description: "The test needs a newer version of Maester." },
  ForeignModuleLoaded: { label: "Foreign module loaded", color: "red", description: "A conflicting module is loaded in the session." },
  PesterNotAvailable: { label: "Pester not available", color: "red", description: "Pester tests were selected but Pester is not available." },
}

export function getReasonInfo(code: string): ReasonInfo {
  return reasonCodes[code] ?? { label: code, color: "gray", description: code }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyRecord = Record<string, any>

// The test a family instance belongs to, when the row is a family instance or a family-level row.
export function getParentId(item: AnyRecord): string | null {
  return item?.ParentId && item.ParentId !== item.Id ? String(item.ParentId) : null
}

// CatalogVersion is a string, or a serialised System.Version ({ Major, Minor, Build, Revision }).
export function formatVersion(value: unknown): string | null {
  if (value === null || value === undefined || value === "") return null
  if (typeof value === "string" || typeof value === "number") return String(value)
  if (typeof value === "object") {
    const v = value as AnyRecord
    if (typeof v.Major === "number") {
      return [v.Major, v.Minor, v.Build, v.Revision].filter((part) => typeof part === "number" && part >= 0).join(".")
    }
  }
  return JSON.stringify(value)
}

// Display text for a free-form value (RunMetadata, test parameters).
export function formatValue(value: unknown): string {
  if (value === null || value === undefined || value === "") return "(not set)"
  if (Array.isArray(value)) return value.map(formatValue).join(", ")
  if (typeof value === "object") {
    const v = value as AnyRecord
    // A UI may store { Id, DisplayName } for a directory object.
    if (v.DisplayName) return v.Id ? `${v.DisplayName} (${v.Id})` : String(v.DisplayName)
    return JSON.stringify(value)
  }
  return String(value)
}

export function asArray<T = unknown>(value: unknown): T[] {
  if (value === null || value === undefined) return []
  return (Array.isArray(value) ? value : [value]) as T[]
}

// True when the result carries any of the 2.1 run-level fields.
export function hasRunConfiguration(results: AnyRecord): boolean {
  return Boolean(results && (results.SchemaVersion || results.Selection || results.TenantContext || results.RunMetadata || results.Partitions))
}
