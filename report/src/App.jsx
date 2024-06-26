import './App.css'
import TestResultsTable from './components/TestResultsTable';
import { Flex, Divider, Grid, Text, Badge, BadgeDelta } from "@tremor/react";
import { CalendarIcon, BuildingOfficeIcon } from "@heroicons/react/24/solid";
import { utcToZonedTime } from 'date-fns-tz'
import ThemeSwitch from "./components/ThemeSwitch";
import { ThemeProvider } from 'next-themes'
import logo from './assets/maester.png';
import MtDonutChart from "./components/MtDonutChart";
import MtTestSummary from "./components/MtTestSummary";
import MtBlocksArea from './components/MtBlocksArea';

/*The sample data will be replaced by the New-MtReport when it runs the generation.*/
const testResults = {
  "Result": "Passed",
  "FailedCount": 0,
  "PassedCount": 0,
  "SkippedCount": 1,
  "TotalCount": 1,
  "ExecutedAt": "2024-06-26T13:56:40.895722+10:00",
  "TenantId": "0817c655-a853-4d8f-9723-3a333b5b9235",
  "TenantName": "Pora",
  "Account": "merill@elapora.com",
  "CurrentVersion": "0.1.0",
  "LatestVersion": "0.1.0",
  "Tests": [
    {
      "Name": "MT.1002: App management restrictions on applications and service principals is configured and enabled.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1002",
      "Tag": [
        "App",
        "Security",
        "All"
      ],
      "Result": "Skipped",
      "ScriptBlock": "\n        Test-MtAppManagementPolicyEnabled | Should -Be $true -Because \"an app policy for workload identities should be defined to enforce strong credentials instead of passwords and a maximum expiry period (e.g. credential should be renewed every six months)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Entra/Test-AppManagementPolicies.Tests.ps1",
      "ErrorRecord": [],
      "Block": "App Management Policies",
      "ResultDetail": null
    }
  ],
  "Blocks": [
    {
      "Name": "App Management Policies",
      "Result": "Skipped",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 1,
      "NotRunCount": 0,
      "TotalCount": 1,
      "Tag": [
        "App",
        "Security",
        "All"
      ]
    }
  ]
};

/* Note: DO NOT place any code between the line 'const testResults = {' and 'function App'.
    They will be stripped away new New-MtReport cmdlet generates the user's content */

function App() {

  const testDateLocal = utcToZonedTime(testResults.ExecutedAt, Intl.DateTimeFormat().resolvedOptions().timeZone).toLocaleString();

  function getTenantName() {
    if (testResults.TenantName == "") return "Tenant ID: " + testResults.TenantId;
    return testResults.TenantName + " (" + testResults.TenantId + ")";
  }

  const NotRunCount = testResults.TotalCount - (testResults.PassedCount + testResults.FailedCount);
  const DonutTotalCount = testResults.PassedCount + testResults.FailedCount; //Don't count skipped tests
  return (

    <ThemeProvider attribute="class" >
      <div className="text-left">
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
          SkippedCount={NotRunCount}
          Result={testResults.Result} />
        <Grid numItemsSm={1} numItemsLg={2} className="gap-6 mb-12 h-50">
          <MtDonutChart
            TotalCount={DonutTotalCount}
            PassedCount={testResults.PassedCount}
            FailedCount={testResults.FailedCount}
            Result={testResults.Result} />
          <MtBlocksArea Blocks={testResults.Blocks} />

        </Grid>

        <Divider />
        <h2 className="text-2xl font-bold mb-6">Test details</h2>
        <div className="grid grid-cols-2 gap-12">

        </div>

        <TestResultsTable TestResults={testResults} />
        <Divider />
        <Grid numItemsSm={2} numItemsLg={2} className="gap-6 mb-6">
          <Text><a href="https://maester.dev" target="_blank" rel="noreferrer">Maester {testResults.CurrentVersion}</a></Text>
          <div className="place-self-end">
            <ThemeSwitch />
          </div>
        </Grid>
      </div>
    </ThemeProvider>
  )
}

export default App
