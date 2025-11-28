import React from 'react';
import { Flex, Divider, Grid, Text, Badge } from "@tremor/react";
import { CalendarIcon, BuildingOfficeIcon } from "@heroicons/react/24/solid";
import logo from '../assets/maester.png';
import MtDonutChart from "./MtDonutChart";
import MtSeverityChart from "./MtSeverityChart";
import MtTestSummary from "./MtTestSummary";
import MtBlocksArea from './MtBlocksArea';
import TestResultsTable from './TestResultsTable';
import ResultInfo from './ResultInfo';

export default function PrintableView({ testResults }) {
  const testDateLocal = new Date(testResults.ExecutedAt).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });

  function getTenantName() {
    if (testResults.TenantName == "") return "Tenant ID: " + testResults.TenantId;
    return testResults.TenantName + " (" + testResults.TenantId + ")";
  }

  const DonutTotalCount = testResults.PassedCount + testResults.FailedCount;

  return (
    <div className="text-left p-8">
      <div className="flex mb-6">
        <img src={logo} className="h-10 w-10 mr-1" alt="Maester logo" />
        <h1 className="text-3xl font-bold self-end">Maester Test Results</h1>
      </div>
      <Flex>
        <Badge className="bg-orange-500 bg-opacity-10 text-orange-600 dark:bg-opacity-60" icon={BuildingOfficeIcon}>{getTenantName()}</Badge>
        <Badge className="bg-orange-500 bg-opacity-10 text-orange-600 dark:bg-opacity-60" icon={CalendarIcon}>{testDateLocal}</Badge>
      </Flex>
      <Divider />
      <h2 className="text-2xl font-bold mb-6">Test summary</h2>
      <MtTestSummary
        TotalCount={testResults.TotalCount}
        PassedCount={testResults.PassedCount}
        FailedCount={testResults.FailedCount}
        SkippedCount={testResults.SkippedCount}
        NotRunCount={testResults.NotRunCount}
        ErrorCount={testResults.ErrorCount}
        Result={testResults.Result} />
      <Grid numItemsSm={1} numItemsLg={3} className="gap-6 mb-12 h-50">
        <MtDonutChart
          TotalCount={DonutTotalCount}
          PassedCount={testResults.PassedCount}
          FailedCount={testResults.FailedCount}
          Result={testResults.Result} />
        <MtSeverityChart Tests={testResults.Tests} hideControls={true} />
        <MtBlocksArea Blocks={testResults.Blocks} />
      </Grid>

      <Divider />
      <h2 className="text-2xl font-bold mb-6">Test details</h2>

      <TestResultsTable TestResults={testResults} isPrintView={true} />

      <Divider />

      <div className="flex flex-col gap-8 mt-8">
        {testResults.Tests.map((test) => (
          <div key={test.Index} className="break-inside-avoid">
            <ResultInfo Item={test} isPrintView={true} />
            <Divider />
          </div>
        ))}
      </div>

      <Grid numItemsSm={2} numItemsLg={2} className="gap-6 mb-6">
        <Text><a href="https://maester.dev" target="_blank" rel="noreferrer">Maester {testResults.CurrentVersion}</a></Text>
      </Grid>
    </div>
  );
}
