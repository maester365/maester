"use client";
import React from "react";
import { Flex, Divider, Grid, Text, Badge } from "@tremor/react";
import { CalendarIcon, BuildingOfficeIcon } from "@heroicons/react/24/solid";
import MtDonutChart from "./MtDonutChart";
import MtSeverityChart from "./MtSeverityChart";
import MtTestSummary from "./MtTestSummary";
import MtBlocksArea from "./MtBlocksArea";
import TestResultsTable from "./TestResultsTable";
import ThemeSwitch from "./ThemeSwitch";

export default function HomeView({ testResults }) {
  const testDateLocal = new Date(testResults.ExecutedAt).toLocaleString(
    undefined,
    { dateStyle: "medium", timeStyle: "short" }
  );

  function getTenantName() {
    if (testResults.TenantName == "")
      return "Tenant ID: " + testResults.TenantId;
    return testResults.TenantName + " (" + testResults.TenantId + ")";
  }

  const DonutTotalCount = testResults.PassedCount + testResults.FailedCount;

  return (
    <div className="text-left">
      <div className="flex mb-6 justify-between items-end">
        <div className="flex flex-col">
          <h1 className="text-3xl font-bold dark:text-white">Test Results</h1>
        </div>
        <ThemeSwitch />
      </div>
      <Flex>
        <Badge
          className="bg-orange-500 bg-opacity-10 text-orange-600 dark:bg-opacity-60"
          icon={BuildingOfficeIcon}
        >
          {getTenantName()}
        </Badge>
        <Badge
          className="bg-orange-500 bg-opacity-10 text-orange-600 dark:bg-opacity-60"
          icon={CalendarIcon}
        >
          {testDateLocal}
        </Badge>
      </Flex>
      <Divider />
      <h2 className="text-2xl font-bold mb-6 dark:text-white">Test summary</h2>
      <MtTestSummary
        TotalCount={testResults.TotalCount}
        PassedCount={testResults.PassedCount}
        FailedCount={testResults.FailedCount}
        SkippedCount={testResults.SkippedCount}
        NotRunCount={testResults.NotRunCount}
        ErrorCount={testResults.ErrorCount}
        Result={testResults.Result}
      />
      <Grid numItemsSm={1} numItemsLg={3} className="gap-6 mb-12 h-50">
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
      <h2 className="text-2xl font-bold mb-6 dark:text-white">Test details</h2>
      <div className="grid grid-cols-2 gap-12"></div>

      <TestResultsTable TestResults={testResults} />
      <Divider />
      <Grid numItemsSm={2} numItemsLg={2} className="gap-6 mb-6">
        <Text>
          <a href="https://maester.dev" target="_blank" rel="noreferrer">
            Maester {testResults.CurrentVersion}
          </a>
        </Text>
      </Grid>
    </div>
  );
}
