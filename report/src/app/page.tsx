"use client"

import { testResults } from "@/lib/testResults"
import { Divider } from "@/components/Divider"
import { RiCalendarLine, RiBuilding2Line } from "@remixicon/react"
import MtTestSummary from "@/components/MtTestSummary"
import MtDonutChart from "@/components/MtDonutChart"
import MtSeverityChart from "@/components/MtSeverityChart"
import MtBlocksArea from "@/components/MtBlocksArea"
import TestResultsTable from "@/components/TestResultsTable"
import { Grid, Text, Badge } from "@tremor/react"

export default function HomePage() {
  const testDateLocal = new Date(testResults.ExecutedAt).toLocaleString(
    undefined,
    { dateStyle: "medium", timeStyle: "short" }
  )

  function getTenantName() {
    if (testResults.TenantName === "")
      return "Tenant ID: " + testResults.TenantId
    return testResults.TenantName + " (" + testResults.TenantId + ")"
  }

  const DonutTotalCount = testResults.PassedCount + testResults.FailedCount

  return (
    <div className="text-left">
      <h1 className="mb-6 text-2xl font-semibold text-gray-900">
        Test Results
      </h1>

      <div className="flex flex-wrap gap-2">
        <Badge
          className="bg-orange-50 text-orange-600"
          icon={RiBuilding2Line}
        >
          {getTenantName()}
        </Badge>
        <Badge
          className="bg-orange-50 text-orange-600"
          icon={RiCalendarLine}
        >
          {testDateLocal}
        </Badge>
      </div>

      <Divider />

      <h2 className="mb-6 text-xl font-semibold text-gray-900">
        Test summary
      </h2>

      <MtTestSummary
        TotalCount={testResults.TotalCount}
        PassedCount={testResults.PassedCount}
        FailedCount={testResults.FailedCount}
        SkippedCount={testResults.SkippedCount}
        NotRunCount={testResults.NotRunCount}
        ErrorCount={testResults.ErrorCount}
        Result={testResults.Result}
      />

      <Grid numItemsSm={1} numItemsLg={3} className="mb-12 gap-6">
        <MtDonutChart
          TotalCount={DonutTotalCount}
          PassedCount={testResults.PassedCount}
          FailedCount={testResults.FailedCount}
          Result={testResults.Result}
        />
        <MtSeverityChart Tests={testResults.Tests} />
        <MtBlocksArea Blocks={testResults.Blocks} />
      </Grid>

      <Divider />

      <h2 className="mb-6 text-xl font-semibold text-gray-900">
        Test details
      </h2>

      <TestResultsTable TestResults={testResults} />

      <Divider />

      <Grid numItemsSm={2} numItemsLg={2} className="mb-6 gap-6">
        <Text>
          <a
            href="https://maester.dev"
            target="_blank"
            rel="noreferrer"
            className="text-orange-500 hover:text-orange-600"
          >
            Maester {testResults.CurrentVersion}
          </a>
        </Text>
      </Grid>
    </div>
  )
}
