import './App.css'
import TestResultsTable from './components/TestResultsTable';
import { Flex, Divider, Grid, Text, Badge } from "@tremor/react";
import { CalendarIcon, OfficeBuildingIcon } from "@heroicons/react/solid";
import { utcToZonedTime } from 'date-fns-tz'
import ThemeSwitch from "./components/ThemeSwitch";
import { ThemeProvider } from 'next-themes'
import logo from './assets/maester.png';
import MtDonutChart from "./components/MtDonutChart";
import MtTestSummary from "./components/MtTestSummary";

/*The sample data will be replaced by the New-MtReport when it runs the generation.*/
const testResults = {
  "Result": "Failed",
  "FailedCount": 4,
  "PassedCount": 3,
  "SkippedCount": 0,
  "TotalCount": 7,
  "ExecutedAt": "2024-01-19T02:21:13.621744+11:00",
  "TenantId": "0817c655-a853-4d8f-9723-3a333b5b9235",
  "TenantName": "Pora Inc.",
  "Account": "merill@elapora.com",
  "Tests": [
    {
      "Name": "ID1002: App management restrictions on applications and service principals is configured and enabled.",
      "HelpUrl": "https://maester.dev/t/ID.1002",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtAppManagementPolicyEnabled | Should -Be $true -Because \"There is no app policy to use secure credentials\"\n    ",
      "ErrorRecord": "Expected $true, because There is no app policy to use secure credentials, but got $false.",
      "Duration": "00:00:00.0611901",
      "Block": "[-] App Management Policies"
    },
    {
      "Name": "ID1001: At least one Conditional Access policy is configured with device compliance.",
      "HelpUrl": "https://maester.dev/t/ID.1001",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaDeviceComplianceExists | Should -Be $true -Because \"There is no policy which requires device compliances\"\n    ",
      "ErrorRecord": "",
      "Duration": "00:00:04.7308833",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1003: At least one Conditional Access policy is configured with All Apps.",
      "HelpUrl": "https://maester.dev/t/ID.1003",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists -SkipCheckAllUsers | Should -Be $true -Because \"There is no policy scoped to All Apps\"\n    ",
      "ErrorRecord": "",
      "Duration": "00:00:00.0036193",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1004: At least one Conditional Access policy is configured with All Apps and All Users.",
      "HelpUrl": "https://maester.dev/t/ID.1004",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists | Should -Be $true -Because \"There is no policy scoped to All Apps and All Users\"\n    ",
      "ErrorRecord": "Expected $true, because There is no policy scoped to All Apps and All Users, but got $false.",
      "Duration": "00:00:00.0058164",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1005: All Conditional Access policies are configured to exclude at least one emergency account or group.",
      "HelpUrl": "https://maester.dev/t/ID.1005",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaEmergencyAccessExists | Should -Be $true -Because \"There is no emergency access account or group present in all enabled policies\"\n    ",
      "ErrorRecord": "Expected $true, because There is no emergency access account or group present in all enabled policies, but got $false.",
      "Duration": "00:00:00.0146871",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1006: At least one Conditional Access policy is configured to require MFA for admins.",
      "HelpUrl": "https://maester.dev/t/ID.1006",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists | Should -Be $true -Because \"There is no policy that requires MFA for admins\"\n    ",
      "ErrorRecord": "Expected $true, because There is no policy that requires MFA for admins, but got $false.",
      "Duration": "00:00:00.0038247",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1007: At least one Conditional Access policy is configured to require MFA for all users.",
      "HelpUrl": "https://maester.dev/t/ID.1007",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaMfaForAllUsers | Should -Be $true -Because \"There is no policy that requires MFA for all users\"\n    ",
      "ErrorRecord": "",
      "Duration": "00:00:00.0020725",
      "Block": "[-] Conditional Access Baseline Policies"
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

  return (
    <ThemeProvider attribute="class" >
      <div className="text-left">
        <div className="flex mb-6">
          <img src={logo} className="h-10 w-10 mr-1" alt="Maester logo" />
          <h1 className="text-3xl font-bold self-end">Maester Test Results</h1>
        </div>
        <Flex>
          <Badge className="bg-blue-200" icon={OfficeBuildingIcon}>{getTenantName()}</Badge>
          <Badge className="bg-blue-200" icon={CalendarIcon}>{testDateLocal}</Badge>
        </Flex>
        <Divider />
        <h2 className="text-2xl font-bold mb-6">Test summary</h2>
        <MtTestSummary
          TotalCount={testResults.TotalCount}
          PassedCount={testResults.PassedCount}
          FailedCount={testResults.FailedCount}
          SkippedCount={testResults.SkippedCount}
          Result={testResults.Result} />
        <Grid numItemsSm={2} numItemsLg={2} className="gap-6 mb-6">
          <MtDonutChart
            TotalCount={testResults.TotalCount}
            PassedCount={testResults.PassedCount}
            FailedCount={testResults.FailedCount}
            SkippedCount={testResults.SkippedCount}
            Result={testResults.Result} />
        </Grid>

        <Divider />
        <h2 className="text-2xl font-bold mb-6">Test details</h2>
        <div className="grid grid-cols-2 gap-12">

        </div>

        <TestResultsTable TestResults={testResults} />
        <Divider />
        <Grid numItemsSm={2} numItemsLg={2} className="gap-6 mb-6">
          <Text><a href="https://maester.dev" target="_blank" rel="noreferrer">Maester.dev</a></Text>
          <div className="place-self-end">
            <ThemeSwitch />
          </div>
        </Grid>
      </div>
    </ThemeProvider>
  )
}

export default App
