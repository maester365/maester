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
  "Result": "Failed",
  "FailedCount": 1,
  "PassedCount": 0,
  "SkippedCount": 0,
  "TotalCount": 284,
  "ExecutedAt": "2025-04-30T21:42:11.493075+10:00",
  "TotalDuration": "00:00:35",
  "UserDuration": "00:00:00",
  "DiscoveryDuration": "00:00:35",
  "FrameworkDuration": "00:00:00",
  "TenantId": "0817c655-a853-4d8f-9723-3a333b5b9235",
  "TenantName": "Entra.Chat",
  "Account": "merill@elapora.com",
  "CurrentVersion": "0.1.0",
  "LatestVersion": "1.0.0",
  "Tests": [
    {
      "Id": "CIS.M365.1.2.1",
      "Title": "(L2) Ensure that only organizationally managed/approved public groups exist",
      "Name": "CIS.M365.1.2.1: (L2) Ensure that only organizationally managed/approved public groups exist",
      "HelpUrl": "",
      "Severity": "Medium",
      "Tag": [
        "CIS.M365.1.2.1",
        "L2",
        "CIS E3 Level 2",
        "CIS E3",
        "CIS",
        "Security",
        "All",
        "CIS M365 v4.0.0",
        "Severity:Medium"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n\n        $result = Test-MtCis365PublicGroup\n\n        if ($null -ne $result) {\n            $result | Should -Be $true -Because \"365 groups are private\"\n        }\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/cis/Test-MtCis365PublicGroup.Tests.ps1",
      "ErrorRecord": [
        {
          "Exception": {
            "TargetSite": null,
            "Message": "Expected $true, because 365 groups are private, but got $false.",
            "Data": "System.Collections.ListDictionaryInternal",
            "InnerException": null,
            "HelpLink": null,
            "Source": null,
            "HResult": -2146233088,
            "StackTrace": null
          },
          "TargetObject": {
            "Message": "Expected $true, because 365 groups are private, but got $false.",
            "File": "/Users/merill/GitHub/maester/tests/cis/Test-MtCis365PublicGroup.Tests.ps1",
            "Line": "7",
            "LineText": "            $result | Should -Be $true -Because \"365 groups are private\"",
            "Terminating": true
          },
          "CategoryInfo": {
            "Category": 8,
            "Activity": "",
            "Reason": "Exception",
            "TargetName": "System.Collections.Generic.Dictionary`2[System.String,System.Object]",
            "TargetType": "Dictionary`2"
          },
          "FullyQualifiedErrorId": "PesterAssertionFailed",
          "ErrorDetails": null,
          "InvocationInfo": {
            "MyCommand": null,
            "BoundParameters": "System.Collections.Generic.Dictionary`2[System.String,System.Object]",
            "UnboundArguments": "",
            "ScriptLineNumber": 8106,
            "OffsetInLine": 13,
            "HistoryId": 68,
            "ScriptName": "/Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1",
            "Line": "            throw $errorRecord\r\n",
            "Statement": "throw $errorRecord",
            "PositionMessage": "At /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1:8106 char:13\n+             throw $errorRecord\n+             ~~~~~~~~~~~~~~~~~~",
            "PSScriptRoot": "/Users/merill/.local/share/powershell/Modules/Pester/5.5.0",
            "PSCommandPath": "/Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1",
            "InvocationName": "",
            "PipelineLength": 0,
            "PipelinePosition": 0,
            "ExpectingInput": false,
            "CommandOrigin": 1,
            "DisplayScriptPosition": null
          },
          "ScriptStackTrace": "at Invoke-Assertion, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 8106\nat Should<End>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 8044\nat <ScriptBlock>, /Users/merill/GitHub/maester/tests/cis/Test-MtCis365PublicGroup.Tests.ps1: line 7\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 2012\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 1973\nat Invoke-ScriptBlock, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 2145\nat Invoke-TestItem, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 1198\nat Invoke-Block, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 834\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 892\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 2012\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 1973\nat Invoke-ScriptBlock, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 2148\nat Invoke-Block, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 939\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 892\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 2012\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 1973\nat Invoke-ScriptBlock, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 2148\nat Invoke-Block, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 939\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 1676\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.ps1: line 3\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 3203\nat Invoke-InNewScriptScope, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 3210\nat Run-Test, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 1679\nat Invoke-Test, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 2500\nat Invoke-Pester<End>, /Users/merill/.local/share/powershell/Modules/Pester/5.5.0/Pester.psm1: line 5046\nat Invoke-Maester, /Users/merill/GitHub/maester/powershell/public/Invoke-Maester.ps1: line 358\nat <ScriptBlock>, <No file>: line 1",
          "PipelineIterationInfo": []
        }
      ],
      "Block": "CIS",
      "Duration": "00:00:00",
      "ResultDetail": "\nYour tenant has 6 public 365 groups:\n\n| Display Name | Group Public |\n| --- | --- |\n| test spo session enforced | ❌ Fail |\n| Watercooler - Public | ❌ Fail |\n| Microsoft 365 Ops Team | ❌ Fail |\n| New group in Graph Explorer! | ❌ Fail |\n| Pora | ❌ Fail |\n| All Company | ❌ Fail |\n"
    },
    {
      "Id": "CIS.M365.1.1.1",
      "Title": "(L1) Ensure Administrative accounts are cloud-only",
      "Name": "CIS.M365.1.1.1: (L1) Ensure Administrative accounts are cloud-only",
      "HelpUrl": "",
      "Severity": "High",
      "Tag": [
        "CIS.M365.1.1.1",
        "L1",
        "CIS E3 Level 1",
        "CIS E3",
        "CIS",
        "Security",
        "All",
        "CIS M365 v4.0.0"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n\n        $result = Test-MtCisCloudAdmin\n\n        if ($null -ne $result) {\n            $result | Should -Be $true -Because \"admin accounts are cloud-only\"\n        }\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/cis/Test-MtCisCloudAdmin.Tests.ps1",
      "ErrorRecord": [],
      "Block": "CIS",
      "Duration": "00:00:00",
      "ResultDetail": null
    },
    {
      "Id": "CIS.M365.1.1.3",
      "Title": "(L1) Ensure that between two and four global admins are designated",
      "Name": "CIS.M365.1.1.3: (L1) Ensure that between two and four global admins are designated",
      "HelpUrl": "",
      "Severity": "High",
      "Tag": [
        "CIS.M365.1.1.3",
        "L1",
        "CIS E3 Level 1",
        "CIS E3",
        "CIS",
        "Security",
        "All",
        "CIS M365 v4.0.0"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n\n        $result = Test-MtCisGlobalAdminCount\n\n        if ($null -ne $result) {\n            $result | Should -Be $true -Because \"only 2-4 Global Administrators exist\"\n        }\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/cis/Test-MtCisGlobalAdminCount.Tests.ps1",
      "ErrorRecord": [],
      "Block": "CIS",
      "Duration": "00:00:00",
      "ResultDetail": null
    },
    {
      "Id": "CIS.M365.1.2.2",
      "Title": "(L1) Ensure sign-in to shared mailboxes is blocked",
      "Name": "CIS.M365.1.2.2: (L1) Ensure sign-in to shared mailboxes is blocked",
      "HelpUrl": "",
      "Severity": "High",
      "Tag": [
        "CIS.M365.1.2.2",
        "L1",
        "CIS E3 Level 1",
        "CIS E3",
        "CIS",
        "Security",
        "All",
        "CIS M365 v4.0.0"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n\n        $result = Test-MtCisSharedMailboxSignIn\n\n        if ($null -ne $result) {\n            $result | Should -Be $true -Because \"Sign ins are blocked for shared mailboxes\"\n        }\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/cis/Test-MtCisSharedMailboxSignIn.Tests.ps1",
      "ErrorRecord": [],
      "Block": "CIS",
      "Duration": "00:00:00",
      "ResultDetail": null
    }
  ],
  "Blocks": [
    {
      "Name": "EIDSCA",
      "Result": "NotRun",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 0,
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AP01"
      ]
    },
    {
      "Name": "CISA",
      "Result": "NotRun",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 0,
      "Tag": [
        "MS.EXO",
        "MS.EXO.12.1",
        "CISA.MS.EXO.12.1",
        "CISA",
        "Security",
        "All"
      ]
    },
    {
      "Name": "Contoso.ConditionalAccess",
      "Result": "NotRun",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 0,
      "Tag": []
    },
    {
      "Name": "CIS",
      "Result": "Failed",
      "FailedCount": 1,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 1,
      "Tag": [
        "CIS.M365.1.2.1",
        "L2",
        "CIS E3 Level 2",
        "CIS E3",
        "CIS",
        "Security",
        "All",
        "CIS M365 v4.0.0"
      ]
    },
    {
      "Name": "Maester/Exchange",
      "Result": "NotRun",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 0,
      "Tag": [
        "Maester",
        "Exchange",
        "SecureScore"
      ]
    },
    {
      "Name": "Maester/Teams",
      "Result": "NotRun",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 0,
      "Tag": [
        "Maester",
        "Teams",
        "MeetingPolicy",
        "All"
      ]
    },
    {
      "Name": "Maester/Intune",
      "Result": "NotRun",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 0,
      "Tag": [
        "Maester",
        "Intune",
        "All"
      ]
    },
    {
      "Name": "Maester/Entra",
      "Result": "NotRun",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 0,
      "Tag": [
        "Maester",
        "App",
        "Security",
        "All"
      ]
    },
    {
      "Name": "ORCA",
      "Result": "NotRun",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 0,
      "Tag": [
        "ORCA",
        "ORCA.100",
        "EXO",
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
