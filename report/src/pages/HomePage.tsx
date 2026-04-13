import { Grid } from "@tremor/react"
import { testResults } from "@/lib/testResults"
import MtTestSummary from "@/components/MtTestSummary"
import MtDonutChart from "@/components/MtDonutChart"
import MtSeverityChart from "@/components/MtSeverityChart"
import MtBlocksArea from "@/components/MtBlocksArea"
import TestResultsTable from "@/components/TestResultsTable"

export default function HomePage() {
  const tenantName = testResults.TenantName || testResults.TenantId || "Tenant"
  const testDateLocal = new Date(testResults.ExecutedAt).toLocaleString(
    undefined,
    {
      dateStyle: "medium",
      timeStyle: "short",
    }
  )

  return (
    <>
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-2xl font-semibold tracking-tight text-gray-900 dark:text-gray-100">
          Test Overview
        </h1>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
          {tenantName} • {testDateLocal}
        </p>
      </div>

      {/* Test Summary */}
      <MtTestSummary {...testResults} />

      {/* Charts Grid */}
      <Grid numItemsMd={2} numItemsLg={3} className="gap-6 mb-6">
        <MtDonutChart {...testResults} />
        <MtSeverityChart Tests={testResults.Tests} />
        <MtBlocksArea Blocks={testResults.Blocks} />
      </Grid>

      {/* Test Results Table */}
      <div className="mt-6">
        <TestResultsTable TestResults={testResults} />
      </div>
    </>
  )
}
