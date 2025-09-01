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

/*The sample data will be replaced by the Get-MtHtmlReport when it runs the generation.*/
const testResults = {
  "Result": "Failed",
  "FailedCount": 2,
  "PassedCount": 0,
  "SkippedCount": 0,
  "TotalCount": 2,
  "ExecutedAt": "2025-05-12T18:33:09.425618+10:00",
  "TotalDuration": "00:00:00",
  "UserDuration": "00:00:00",
  "DiscoveryDuration": "00:00:00",
  "FrameworkDuration": "00:00:00",
  "TenantId": "0817c655-a853-4d8f-9723-3a333b5b9235",
  "TenantName": "Pora Inc.",
  "Account": "merill@elapora.com",
  "CurrentVersion": "0.1.0",
  "LatestVersion": "1.0.0",
  "Tests": [
    {
      "Index": 1,
      "Id": "MT.1053",
      "Title": "Ensure intune device clean-up rule is configured",
      "Name": "MT.1053: Ensure intune device clean-up rule is configured",
      "HelpUrl": "",
      "Severity": "Medium",
      "Tag": [
        "Maester",
        "Intune",
        "MT.1053"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Test-MtManagedDeviceCleanupSettings\n        if ($null -ne $result) {\n            $result | Should -Be $true -Because \"automatic device clean-up rule is configured.\"\n        }\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Intune/Test-MtIntunePlatform.Tests.ps1",
      "ErrorRecord": [
        {
          "Exception": {
            "TargetSite": null,
            "Message": "Expected $true, because automatic device clean-up rule is configured., but got $false.",
            "Data": "System.Collections.ListDictionaryInternal",
            "InnerException": null,
            "HelpLink": null,
            "Source": null,
            "HResult": -2146233088,
            "StackTrace": null
          },
          "TargetObject": {
            "Message": "Expected $true, because automatic device clean-up rule is configured., but got $false.",
            "File": "/Users/merill/GitHub/maester/tests/Maester/Intune/Test-MtIntunePlatform.Tests.ps1",
            "Line": "5",
            "LineText": "            $result | Should -Be $true -Because \"automatic device clean-up rule is configured.\"",
            "Terminating": true,
            "ShouldResult": "Pester.ShouldResult"
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
            "ScriptLineNumber": 8392,
            "OffsetInLine": 13,
            "HistoryId": 9,
            "ScriptName": "/Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1",
            "Line": "            throw $errorRecord\r\n",
            "Statement": "throw $errorRecord",
            "PositionMessage": "At /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1:8392 char:13\n+             throw $errorRecord\n+             ~~~~~~~~~~~~~~~~~~",
            "PSScriptRoot": "/Users/merill/.local/share/powershell/Modules/Pester/5.6.1",
            "PSCommandPath": "/Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1",
            "InvocationName": "",
            "PipelineLength": 0,
            "PipelinePosition": 0,
            "ExpectingInput": false,
            "CommandOrigin": 1,
            "DisplayScriptPosition": null
          },
          "ScriptStackTrace": "at Invoke-Assertion, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 8392\nat Should<End>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 8331\nat <ScriptBlock>, /Users/merill/GitHub/maester/tests/Maester/Intune/Test-MtIntunePlatform.Tests.ps1: line 5\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2024\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 1985\nat Invoke-ScriptBlock, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2157\nat Invoke-TestItem, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 1199\nat Invoke-Block, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 835\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 893\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2024\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 1985\nat Invoke-ScriptBlock, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2160\nat Invoke-Block, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 940\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 893\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2024\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 1985\nat Invoke-ScriptBlock, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2160\nat Invoke-Block, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 940\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 1688\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.ps1: line 3\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 3260\nat Invoke-InNewScriptScope, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 3267\nat Run-Test, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 1691\nat Invoke-Test, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2512\nat Invoke-Pester<End>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 5110\nat Invoke-Maester, /Users/merill/GitHub/maester/powershell/public/Invoke-Maester.ps1: line 377\nat <ScriptBlock>, <No file>: line 1",
          "PipelineIterationInfo": []
        }
      ],
      "Block": "Maester/Intune",
      "Duration": "00:00:00",
      "ResultDetail": {
        "TestTitle": "MT.1053: Ensure intune device clean-up rule is configured",
        "SkippedReason": null,
        "TestSkipped": "",
        "Service": null,
        "TestDescription": "Ensure device clean-up rule is configured\n\nThis test checks if the device clean-up rule is configured.\n\nSet your Intune device cleanup rules to delete Intune MDM enrolled devices that appear inactive, stale, or unresponsive. Intune applies cleanup rules immediately and continuously so that your device records remain current.\n\n#### Remediation action:\n\nTo enable device clean-up rules:\n1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).\n2. Click **Devices** scroll down to **Organize devices**.\n3. Select **Device clean-up rules**.\n4. Set **Delete devices based on last check-in date** to **Yes**\n5. Set **Delete devices that haven’t checked in for this many days** to **30 days or more** depending on your organizational needs.\n6. Click **Save**.\n\n#### Related links\n\n* [Microsoft 365 Admin Center](https://admin.microsoft.com)\n* [Microsoft Intune - Device clean-up rules](https://intune.microsoft.com/?ref=AdminCenter#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/deviceCleanUp)\n\n",
        "Severity": "",
        "TestResult": "\nYour Intune device clean-up rule is not configured."
      }
    },
    {
      "Index": 2,
      "Id": "MT.1054",
      "Title": "Ensure built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'",
      "Name": "MT.1054: Ensure built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'",
      "HelpUrl": "",
      "Severity": "Medium",
      "Tag": [
        "Maester",
        "Intune",
        "MT.1054"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Test-MtDeviceComplianceSettings\n        if ($null -ne $result) {\n            $result | Should -Be $true -Because \"built-in device compliance policy marks devices with no policy assigned as 'Not compliant'.\"\n        }\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Intune/Test-MtIntunePlatform.Tests.ps1",
      "ErrorRecord": [
        {
          "Exception": {
            "TargetSite": null,
            "Message": "Expected $true, because built-in device compliance policy marks devices with no policy assigned as 'Not compliant'., but got $false.",
            "Data": "System.Collections.ListDictionaryInternal",
            "InnerException": null,
            "HelpLink": null,
            "Source": null,
            "HResult": -2146233088,
            "StackTrace": null
          },
          "TargetObject": {
            "Message": "Expected $true, because built-in device compliance policy marks devices with no policy assigned as 'Not compliant'., but got $false.",
            "File": "/Users/merill/GitHub/maester/tests/Maester/Intune/Test-MtIntunePlatform.Tests.ps1",
            "Line": "12",
            "LineText": "            $result | Should -Be $true -Because \"built-in device compliance policy marks devices with no policy assigned as 'Not compliant'.\"",
            "Terminating": true,
            "ShouldResult": "Pester.ShouldResult"
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
            "ScriptLineNumber": 8392,
            "OffsetInLine": 13,
            "HistoryId": 9,
            "ScriptName": "/Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1",
            "Line": "            throw $errorRecord\r\n",
            "Statement": "throw $errorRecord",
            "PositionMessage": "At /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1:8392 char:13\n+             throw $errorRecord\n+             ~~~~~~~~~~~~~~~~~~",
            "PSScriptRoot": "/Users/merill/.local/share/powershell/Modules/Pester/5.6.1",
            "PSCommandPath": "/Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1",
            "InvocationName": "",
            "PipelineLength": 0,
            "PipelinePosition": 0,
            "ExpectingInput": false,
            "CommandOrigin": 1,
            "DisplayScriptPosition": null
          },
          "ScriptStackTrace": "at Invoke-Assertion, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 8392\nat Should<End>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 8331\nat <ScriptBlock>, /Users/merill/GitHub/maester/tests/Maester/Intune/Test-MtIntunePlatform.Tests.ps1: line 12\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2024\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 1985\nat Invoke-ScriptBlock, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2157\nat Invoke-TestItem, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 1199\nat Invoke-Block, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 835\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 893\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2024\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 1985\nat Invoke-ScriptBlock, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2160\nat Invoke-Block, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 940\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 893\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2024\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 1985\nat Invoke-ScriptBlock, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2160\nat Invoke-Block, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 940\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 1688\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.ps1: line 3\nat <ScriptBlock>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 3260\nat Invoke-InNewScriptScope, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 3267\nat Run-Test, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 1691\nat Invoke-Test, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 2512\nat Invoke-Pester<End>, /Users/merill/.local/share/powershell/Modules/Pester/5.6.1/Pester.psm1: line 5110\nat Invoke-Maester, /Users/merill/GitHub/maester/powershell/public/Invoke-Maester.ps1: line 377\nat <ScriptBlock>, <No file>: line 1",
          "PipelineIterationInfo": []
        }
      ],
      "Block": "Maester/Intune",
      "Duration": "00:00:00",
      "ResultDetail": {
        "TestTitle": "MT.1054: Ensure built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'",
        "SkippedReason": null,
        "TestSkipped": "",
        "Service": null,
        "TestDescription": "Ensure the built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'.\n\nSet your Intune built-in Device Compliance Policy to mark devices with no compliance policy assigned as 'Not compliant'.\nThis ensures that new devices that do not have any policies assigned are not compliant per default.\n\n#### Remediation action:\n\nTo change the built-in device compliance policy:\n1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).\n2. Click **Devices** scroll down to **Manage devices**.\n3. Select **Compliance** and Select **Compliance settings**.\n4. Set **Mark devices with no compliance policy assigned as** to **Not compliant**\n5. Click **Save**.\n\n#### Related links\n\n* [Microsoft 365 Admin Center](https://admin.microsoft.com)\n* [Microsoft Intune - Compliance](https://intune.microsoft.com/?ref=AdminCenter#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)\n* [Compliance policy settings](https://learn.microsoft.com/de-de/mem/intune/protect/device-compliance-get-started#compliance-policy-settings)\n\n",
        "Severity": "",
        "TestResult": "\nYour Intune built-in Device Compliance Policy **incorrectly** marks devices with no compliance policy assigned as 'Compliant'."
      }
    }
  ],
  "Blocks": [
    {
      "Name": "Maester/Intune",
      "Result": "Failed",
      "FailedCount": 2,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 2,
      "Tag": [
        "Maester",
        "Intune"
      ]
    }
  ]
};

/* Note: DO NOT place any code between the line 'const testResults = {' and 'function App'.
    They will be stripped away when Get-MtHtmlReport cmdlet generates the user's content */

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
