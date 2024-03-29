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
import MtBlocksArea from './components/MtBlocksArea';

/*The sample data will be replaced by the New-MtReport when it runs the generation.*/
const testResults = {
  "Result": "Failed",
  "FailedCount": 14,
  "PassedCount": 5,
  "SkippedCount": 0,
  "TotalCount": 19,
  "ExecutedAt": "2024-03-23T14:25:29.432648+11:00",
  "TenantId": "0817c655-a853-4d8f-9723-3a333b5b9235",
  "TenantName": "Pora",
  "Account": "merill@elapora.com",
  "Tests": [
    {
      "Name": "MT.1001: At least one Conditional Access policy is configured with device compliance.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1001",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaDeviceComplianceExists | Should -Be $true -Because \"there is no policy which requires device compliances\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1003: At least one Conditional Access policy is configured with All Apps.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1003",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists -SkipCheckAllUsers | Should -Be $true -Because \"there is no policy scoped to All Apps\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1004: At least one Conditional Access policy is configured with All Apps and All Users.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1004",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists | Should -Be $true -Because \"there is no policy scoped to All Apps and All Users\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1005: All Conditional Access policies are configured to exclude at least one emergency/break glass account or group.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1005",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaEmergencyAccessExists | Should -Be $true -Because \"there is no emergency access account or group present in all enabled policies\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no emergency access account or group present in all enabled policies, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": {
        "TestResult": "These conditional access policies don't have the emergency access account or group excluded:\n\n- ACSC - L2\n- AppProtect\n- Block Device Code\n- Device compliance #1\n- Device compliancy\n- Force Password Change\n- Guest 10 hr MFA\n- Guest-Meferna-Woodgrove-PhishingResistantAuthStrength\n- j-test admin\n- MFA - All users\n- MFA CA Policy\n- nestedgroup count\n- No persistence\n- O365\n- Register device\n- Require multifactor authentication for Microsoft admin portals\n- SPO\n- TestEntraExporterNullCA Issue\n",
        "TestDescription": "It is recommended to have at least one emergency/break glass account or account group excluded from all conditional access policies.\n        This allows for emergency access to the tenant in case of a misconfiguration or other issues.\n\nSee [Manage emergency access accounts in Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access)"
      }
    },
    {
      "Name": "MT.1006: At least one Conditional Access policy is configured to require MFA for admins.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1006",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists | Should -Be $true -Because \"there is no policy that requires MFA for admins\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1007: At least one Conditional Access policy is configured to require MFA for all users.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1007",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaMfaForAllUsers | Should -Be $true -Because \"there is no policy that requires MFA for all users\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1008: At least one Conditional Access policy is configured to require MFA for Azure management.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1008",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaMfaForAdminManagement | Should -Be $true -Because \"there is no policy that requires MFA for Azure management\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that requires MFA for Azure management, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1009: At least one Conditional Access policy is configured to block other legacy authentication.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1009",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaBlockLegacyOtherAuthentication | Should -Be $true -Because \"there is no policy that blocks legacy authentication\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that blocks legacy authentication, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1010: At least one Conditional Access policy is configured to block legacy authentication for Exchange ActiveSync.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1010",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaBlockLegacyExchangeActiveSyncAuthentication | Should -Be $true -Because \"there is no policy that blocks legacy authentication for Exchange ActiveSync\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that blocks legacy authentication for Exchange ActiveSync, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1011: At least one Conditional Access policy is configured to secure security info registration only from a trusted location.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1011",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaSecureSecurityInfoRegistration | Should -Be $true -Because \"there is no policy that secures security info registration\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that secures security info registration, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1012: At least one Conditional Access policy is configured to require MFA for risky sign-ins.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1012",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaMfaForRiskySignIn | Should -Be $true -Because \"there is no policy that requires MFA for risky sign-ins\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that requires MFA for risky sign-ins, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1013: At least one Conditional Access policy is configured to require new password when user risk is high.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1013",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaRequirePasswordChangeForHighUserRisk | Should -Be $true -Because \"there is no policy that requires new password when user risk is high\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that requires new password when user risk is high, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1014: At least one Conditional Access policy is configured to require compliant or Entra hybrid joined devices for admins.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1014",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaDeviceComplianceAdminsExists | Should -Be $true -Because \"there is no policy that requires compliant or Entra hybrid joined devices for admins\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that requires compliant or Entra hybrid joined devices for admins, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1015: At least one Conditional Access policy is configured to block access for unknown or unsupported device platforms.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1015",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaBlockUnknownOrUnsupportedDevicePlatform | Should -Be $true -Because \"there is no policy that blocks access for unknown or unsupported device platforms\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that blocks access for unknown or unsupported device platforms, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1016: At least one Conditional Access policy is configured to require MFA for guest access.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1016",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaMfaForGuest | Should -Be $true -Because \"there is no policy that requires MFA for guest access\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that requires MFA for guest access, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1017: At least one Conditional Access policy is configured to enforce non persistent browser session for non-corporate devices.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1017",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaEnforceNonPersistentBrowserSession | Should -Be $true -Because \"there is no policy that enforces non persistent browser session for non-corporate devices\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that enforces non persistent browser session for non-corporate devices, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1018: At least one Conditional Access policy is configured to enforce sign-in frequency for non-corporate devices.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1018",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaEnforceSignInFrequency | Should -Be $true -Because \"there is no policy that enforces sign-in frequency for non-corporate devices\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that enforces sign-in frequency for non-corporate devices, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1019: At least one Conditional Access policy is configured to enable application enforced restrictions.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1019",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaApplicationEnforcedRestriction | Should -Be $true -Because \"there is no policy that enables application enforced restrictions\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that enables application enforced restrictions, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    },
    {
      "Name": "MT.1020: All Conditional Access policies are configured to exclude directory synchronization accounts or do not scope them.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1020",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaExclusionForDirectorySyncAccount | Should -Be $true -Because \"there is no policy that excludes directory synchronization accounts\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because there is no policy that excludes directory synchronization accounts, but got $false."
      ],
      "Block": "Conditional Access Baseline Policies",
      "ResultDetail": null
    }
  ],
  "Blocks": [
    {
      "Name": "Conditional Access Baseline Policies",
      "Result": "Failed",
      "FailedCount": 14,
      "PassedCount": 5,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 19,
      "Tag": [
        "CA",
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
  testResults.TotalCount = testResults.PassedCount + testResults.FailedCount; //Don't count skipped tests
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
          SkippedCount={NotRunCount}
          Result={testResults.Result} />
        <Grid numItemsSm={1} numItemsLg={2} className="gap-6 mb-12 h-50">
          <MtDonutChart
            TotalCount={testResults.TotalCount}
            PassedCount={testResults.PassedCount}
            FailedCount={testResults.FailedCount}
            SkippedCount={NotRunCount}
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
