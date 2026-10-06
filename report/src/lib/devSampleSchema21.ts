// Development only: decorates the 2.x sample in testResults.ts with result schema 2.1 fields so the
// Maester 3.0 UI can be exercised with `npm run dev`. Pick a variant with the page query string:
//   ?sample=2.1         single result with the 2.1 fields
//   ?sample=partitions  2.1 result merged with Merge-MtMaesterResult -SameRun (Partitions)
//   ?sample=tenants     two 2.1 results merged into a multi-tenant Tenants array
// Without a query string the unchanged 2.x sample loads.

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyRecord = Record<string, any>

const skipReasons = ["ServiceNotConnected", "LicenseNotFound", "NotApplicable", "TestSkipped"]
const notRunReasons = ["NotSelected", "Preview", "LongRunning", "ExcludedByTag"]

function decorate(source: AnyRecord, tenantSuffix = ""): AnyRecord {
  const results: AnyRecord = structuredClone(source)
  let familyCount = 0
  results.Tests = results.Tests.map((test: AnyRecord, index: number) => {
    const row: AnyRecord = { ...test }
    const isNative = /^(MT|CIS|CISA)\./.test(row.Id || "") && index % 3 !== 0
    row.Format = isNative ? "Native" : "Pester"
    row.Source = "BuiltIn"
    row.Suite = (row.Id || "Custom").split(".")[0]
    row.ReasonCode = null
    row.ReasonDetail = null
    row.ParentId = null
    row.InstanceId = null
    row.Parameters = null
    row.Diagnostics = []
    if (row.Result === "Skipped") {
      row.ReasonCode = skipReasons[index % skipReasons.length]
      row.ReasonDetail = row.ResultDetail?.SkippedReason || "Not connected to Exchange Online. See Connect-Maester."
    } else if (row.Result === "NotRun") {
      row.ReasonCode = notRunReasons[index % notRunReasons.length]
      row.ReasonDetail = `Excluded by the ${row.ReasonCode} rule.`
    } else if (row.Result === "Error") {
      row.ReasonCode = "TestError"
      row.ReasonDetail = "The remote server returned an error: (403) Forbidden."
      row.Diagnostics = ["WARNING: Retrying request after throttling.", "ERROR: The remote server returned an error: (403) Forbidden."]
    }
    if (isNative && row.Result === "Failed" && familyCount < 3) {
      familyCount++
      row.ParentId = "MT.1101"
      row.InstanceId = `MT.1101.policy-${familyCount}`
      row.Parameters = [
        { Name: "ExcludedGroup", Value: { Id: "8f1c-41d2", DisplayName: "Break glass accounts" }, Source: "Config", Kind: "Group" },
        { Name: "MaxAgeDays", Value: 90, Source: "Default", Kind: "Int" },
      ]
    }
    return row
  })
  results.SchemaVersion = "2.1"
  results.CatalogVersion = { Major: 3, Minor: 0, Build: 0, Revision: -1, MajorRevision: -1, MinorRevision: -1 }
  results.TenantContext = {
    TenantId: results.TenantId,
    TenantName: results.TenantName + tenantSuffix,
    TenantType: "Workforce",
    Cloud: "Global",
    Platform: "MacOS",
    Services: { Graph: true, ExchangeOnline: true, Teams: false, SharePointOnline: false, Azure: true, SecurityCompliance: false },
    Licenses: { State: "Known", ServicePlanNames: ["AAD_PREMIUM", "AAD_PREMIUM_P2", "EXCHANGE_S_ENTERPRISE"], Source: "Graph" },
    AuthType: "Delegated",
    Account: "admin@contoso.com",
  }
  results.RunMetadata = { RunId: "nightly-2026-10-06", Pipeline: "azure-devops/maester-nightly", Owner: "secops" }
  results.Selection = {
    BuiltIn: "All",
    UnknownIds: ["MT.9999", "CIS.M365.99.1"],
    Superseded: [
      { Id: "MT.1001", File: "./tests/Maester/Entra/Test-ConditionalAccessBaseline.Tests.ps1", MatchedBy: "Id" },
      { Id: "CISA.MS.AAD.7.1", File: "./tests/cisa/entra/Test-MtCisaGlobalAdminCount.Tests.ps1", MatchedBy: "LegacyId" },
    ],
    IncludeTag: ["Maester", "CIS"],
    ExcludeTag: ["Preview", "LongRunning"],
    DryRun: false,
  }
  return results
}

export function applyDevSample(source: AnyRecord, variant: string | null): AnyRecord {
  if (variant === "2.1") return decorate(source)
  if (variant === "partitions") {
    const merged = decorate(source)
    merged.Partitions = [
      { TenantId: merged.TenantId, TenantContext: merged.TenantContext, ExecutedAt: merged.ExecutedAt, TotalDuration: "00:02:10", Result: "Failed", TotalCount: 180, InvokeCommand: "Invoke-Maester -Tag Graph -PassThru" },
      { TenantId: merged.TenantId, TenantContext: merged.TenantContext, ExecutedAt: merged.ExecutedAt, TotalDuration: "00:03:36", Result: "Passed", TotalCount: 135, InvokeCommand: "Invoke-Maester -Tag EXO -PassThru" },
    ]
    // Merge-MtPartitionResult rebuilds Selection with only these three keys.
    merged.Selection = { BuiltIn: merged.Selection.BuiltIn, UnknownIds: merged.Selection.UnknownIds, Superseded: merged.Selection.Superseded }
    return merged
  }
  if (variant === "tenants") {
    const second = decorate(source, " (EU)")
    second.TenantName = `${source.TenantName} (EU)`
    second.TenantId = "5a1f3c2e-0000-4000-8000-00000000e0e0"
    second.TenantContext.TenantId = second.TenantId
    second.Selection.DryRun = true
    return { Tenants: [decorate(source), second], CurrentVersion: source.CurrentVersion, LatestVersion: source.LatestVersion, EndOfJson: "EndOfJson" }
  }
  return source
}
