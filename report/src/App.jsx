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
  "FailedCount": 33,
  "PassedCount": 30,
  "SkippedCount": 1,
  "TotalCount": 64,
  "ExecutedAt": "2024-03-30T21:01:43.730648+11:00",
  "TenantId": "0817c655-a853-4d8f-9723-3a333b5b9235",
  "TenantName": "Pora",
  "Account": "merill@elapora.com",
  "Tests": [
    {
      "Name": "EIDSCA.AF01: Authentication Method - FIDO2 security key - State.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AF01",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AF01"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\"\n         .state = 'enabled'\n      #>\n      Test-MtEidscaAF01 | Should -Be 'enabled'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - FIDO2 security key",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**\n",
        "TestDescription": "Whether the FIDO2 security keys is enabled in the tenant.\n\nenabled\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\n.state = 'enabled'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AF02: Authentication Method - FIDO2 security key - Allow self-service set up.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AF02",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AF02"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\"\n         .isSelfServiceRegistrationAllowed = 'true'\n      #>\n      Test-MtEidscaAF02 | Should -Be 'true'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - FIDO2 security key",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'true'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**\n",
        "TestDescription": "Allows users to register a FIDO key through the MySecurityInfo portal, even if enabled by Authentication Methods policy.\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\n.isSelfServiceRegistrationAllowed = 'true'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AF03: Authentication Method - FIDO2 security key - Enforce attestation.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AF03",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AF03"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\"\n         .isAttestationEnforced = 'true'\n      #>\n      Test-MtEidscaAF03 | Should -Be 'true'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - FIDO2 security key",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'true'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**\n",
        "TestDescription": "Requires the FIDO security key metadata to be published and verified with the FIDO Alliance Metadata Service, and also pass Microsoft???s additional set of validation testing.\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\n.isAttestationEnforced = 'true'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AF06: Authentication Method - FIDO2 security key - Restrict specific keys.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AF06",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AF06"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\"\n         .keyRestrictions.enforcementType = 'block'\n      #>\n      Test-MtEidscaAF06 | Should -Be 'block'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - FIDO2 security key",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'block'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**\n",
        "TestDescription": "Defines if list of AADGUID will be used to allow or block registration.\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\n.keyRestrictions.enforcementType = 'block'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AG01: Authentication Method - General Settings - Manage migration.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AG01",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AG01"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy\"\n         .policyMigrationState = 'migrationComplete'\n      #>\n      Test-MtEidscaAG01 | Should -Be 'migrationComplete'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, but they were different.\nExpected length: 17\nActual length:   19\nStrings differ at index 9.\nExpected: 'migrationComplete'\nBut was:  'migrationInProgress'\n           ---------^"
      ],
      "Block": "Authentication Method - General Settings",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **migrationInProgress**.\n\nThe recommended value is **'migrationComplete'** for **policies/authenticationMethodsPolicy**\n",
        "TestDescription": "The state of migration of the authentication methods policy from the legacy multifactor authentication and self-service password reset (SSPR) policies. In January 2024, the legacy multifactor authentication and self-service password reset policies will be deprecated and you'll manage all authentication methods here in the authentication methods policy. Use this control to manage your migration from the legacy policies to the new unified policy.\n\nIn January 2024, the legacy multifactor authentication and self-service password reset policies will be deprecated and you'll manage all authentication methods here in the authentication methods policy. Use this control to manage your migration from the legacy policies to the new unified policy.\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy\n.policyMigrationState = 'migrationComplete'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [Get authenticationMethodsPolicy - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)\n\n"
      }
    },
    {
      "Name": "EIDSCA.AG02: Authentication Method - General Settings - Report suspicious activity - State.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AG02",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AG02"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy\"\n         .reportSuspiciousActivitySettings.state = 'enabled'\n      #>\n      Test-MtEidscaAG02 | Should -Be 'enabled'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, but they were different.\nString lengths are both 7.\nStrings differ at index 0.\nExpected: 'enabled'\nBut was:  'default'\n           ^"
      ],
      "Block": "Authentication Method - General Settings",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **default**.\n\nThe recommended value is **'enabled'** for **policies/authenticationMethodsPolicy**\n",
        "TestDescription": "Allows users to report suspicious activities if they receive an authentication request that they did not initiate. This control is available when using the Microsoft Authenticator app and voice calls. Reporting suspicious activity will set the user's risk to high. If the user is subject to risk-based Conditional Access policies, they may be blocked.\n\nAllows to integrate report of fraud attempt by users to identity protection: Users who report an MFA prompt as suspicious are set to High User Risk. Administrators can use risk-based policies to limit access for these users, or enable self-service password reset (SSPR) for users to remediate problems on their own.\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy\n.reportSuspiciousActivitySettings.state = 'enabled'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [Get authenticationMethodsPolicy - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)\n\n"
      }
    },
    {
      "Name": "EIDSCA.AG03: Authentication Method - General Settings - Report suspicious activity - Included users/groups.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AG03",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AG03"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy\"\n         .reportSuspiciousActivitySettings.includeTarget.id = 'all_users'\n      #>\n      Test-MtEidscaAG03 | Should -Be 'all_users'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - General Settings",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'all_users'** for **policies/authenticationMethodsPolicy**\n",
        "TestDescription": "Object Id or scope of users which will be included to report suspicious activities if they receive an authentication request that they did not initiate.\n\nApply this feature to all users.\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy\n.reportSuspiciousActivitySettings.includeTarget.id = 'all_users'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [Get authenticationMethodsPolicy - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)\n\n"
      }
    },
    {
      "Name": "EIDSCA.AM01: Authentication Method - Microsoft Authenticator - State.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AM01",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AM01"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\"\n         .state = 'enabled'\n      #>\n      Test-MtEidscaAM01 | Should -Be 'enabled'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**\n",
        "TestDescription": "Whether the Authenticator App is enabled in the tenant.\n\nenabled\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\n.state = 'enabled'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AM02: Authentication Method - Microsoft Authenticator - Allow use of Microsoft Authenticator OTP.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AM02",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AM02"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\"\n         .state = 'enabled'\n      #>\n      Test-MtEidscaAM02 | Should -Be 'enabled'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**\n",
        "TestDescription": "Defines if users can use the OTP code generated by the Authenticator App.\n\nenabled\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\n.state = 'enabled'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AM03: Authentication Method - Microsoft Authenticator - Require number matching for push notifications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AM03",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AM03"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\"\n         .featureSettings.numberMatchingRequiredState.state = 'enabled'\n      #>\n      Test-MtEidscaAM03 | Should -Be 'enabled'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**\n",
        "TestDescription": "Defines if number matching is required for MFA notifications.\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\n.featureSettings.numberMatchingRequiredState.state = 'enabled'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AM04: Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AM04",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AM04"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\"\n         .featureSettings.numberMatchingRequiredState.includeTarget.id = 'all_users'\n      #>\n      Test-MtEidscaAM04 | Should -Be 'all_users'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**\n",
        "TestDescription": "Object Id or scope of users which will be showing number matching in the Authenticator App.\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\n.featureSettings.numberMatchingRequiredState.includeTarget.id = 'all_users'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AM06: Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AM06",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AM06"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\"\n         .featureSettings.displayAppInformationRequiredState.state = 'enabled'\n      #>\n      Test-MtEidscaAM06 | Should -Be 'enabled'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**\n",
        "TestDescription": "Determines whether the user's Authenticator app will show them the client app they are signing into.\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\n.featureSettings.displayAppInformationRequiredState.state = 'enabled'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AM07: Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AM07",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AM07"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\"\n         .featureSettings.displayAppInformationRequiredState.includeTarget.id = 'all_users'\n      #>\n      Test-MtEidscaAM07 | Should -Be 'all_users'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**\n",
        "TestDescription": "Object Id or scope of users which will be showing app information in the Authenticator App.\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\n.featureSettings.displayAppInformationRequiredState.includeTarget.id = 'all_users'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AM09: Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AM09",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AM09"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\"\n         .featureSettings.displayLocationInformationRequiredState.state = 'enabled'\n      #>\n      Test-MtEidscaAM09 | Should -Be 'enabled'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**\n",
        "TestDescription": "Determines whether the user's Authenticator app will show them the geographic location of where the authentication request originated from.\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\n.featureSettings.displayLocationInformationRequiredState.state = 'enabled'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AM10: Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AM10",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AM10"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\"\n         .featureSettings.displayLocationInformationRequiredState.includeTarget.id = 'all_users'\n      #>\n      Test-MtEidscaAM10 | Should -Be 'all_users'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**\n",
        "TestDescription": "Object Id or scope of users which will be showing geographic location in the Authenticator App.\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\n.featureSettings.displayLocationInformationRequiredState.includeTarget.id = 'all_users'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AP01: Default Authorization Settings - Enabled Self service password reset.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AP01",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AP01"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authorizationPolicy\"\n         .allowedToUseSSPR = 'true'\n      #>\n      Test-MtEidscaAP01 | Should -Be 'true'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Authorization Settings",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'true'** for **policies/authorizationPolicy**\n",
        "TestDescription": "Designates whether users in this directory can reset their own password.\n\n[Azure identity & access security best practices - Microsoft Learn](https://learn.microsoft.com/en-us/azure/security/fundamentals/identity-management-best-practices#enable-password-management)\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authorizationPolicy\n.allowedToUseSSPR = 'true'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [authorizationPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/PasswordResetMenuBlade/~/Properties)\n\n"
      }
    },
    {
      "Name": "EIDSCA.AP04: Default Authorization Settings - Guest invite restrictions.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AP04",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AP04"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authorizationPolicy\"\n         .allowInvitesFrom = 'adminsAndGuestInviters'\n      #>\n      Test-MtEidscaAP04 | Should -Be 'adminsAndGuestInviters'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, but they were different.\nExpected length: 22\nActual length:   8\nStrings differ at index 0.\nExpected: 'adminsAndGuestInviters'\nBut was:  'everyone'\n           ^"
      ],
      "Block": "Default Authorization Settings",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **everyone**.\n\nThe recommended value is **'adminsAndGuestInviters'** for **policies/authorizationPolicy**\n",
        "TestDescription": "Manages controls who can invite guests to your directory to collaborate on resources secured by your Azure AD, such as SharePoint sites or Azure resources.\n\nCISA SCuBA 2.18: Only users with the Guest Inviter role SHOULD be able to invite guest users\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authorizationPolicy\n.allowInvitesFrom = 'adminsAndGuestInviters'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [authorizationPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/Settings)\n\n"
      }
    },
    {
      "Name": "EIDSCA.AP05: Default Authorization Settings - Sign-up for email based subscription.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AP05",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AP05"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authorizationPolicy\"\n         .allowedToSignUpEmailBasedSubscriptions = 'false'\n      #>\n      Test-MtEidscaAP05 | Should -Be 'false'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'false', but got $true."
      ],
      "Block": "Default Authorization Settings",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'false'** for **policies/authorizationPolicy**\n",
        "TestDescription": "Indicates whether users can sign up for email based subscriptions.\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authorizationPolicy\n.allowedToSignUpEmailBasedSubscriptions = 'false'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [authorizationPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AP06: Default Authorization Settings - User can joint the tenant by email validation.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AP06",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AP06"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authorizationPolicy\"\n         .allowEmailVerifiedUsersToJoinOrganization = 'false'\n      #>\n      Test-MtEidscaAP06 | Should -Be 'false'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'false', but got $true."
      ],
      "Block": "Default Authorization Settings",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'false'** for **policies/authorizationPolicy**\n",
        "TestDescription": "Controls whether users can join the tenant by email validation. To join, the user must have an email address in a domain which matches one of the verified domains in the tenant.\n\n[Self-service sign up for email-verified users - Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/enterprise-users/directory-self-service-signup)\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authorizationPolicy\n.allowEmailVerifiedUsersToJoinOrganization = 'false'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [authorizationPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AP07: Default Authorization Settings - Guest user access.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AP07",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AP07"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authorizationPolicy\"\n         .guestUserRoleId = '2af84b1e-32c8-42b7-82bc-daa82404023b'\n      #>\n      Test-MtEidscaAP07 | Should -Be '2af84b1e-32c8-42b7-82bc-daa82404023b'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, but they were different.\nString lengths are both 36.\nStrings differ at index 0.\nExpected: '2af84b1e-32c8-42b7-82bc-daa82404023b'\nBut was:  '10dae51f-b6af-4016-8d66-8c2a99b929b3'\n           ^"
      ],
      "Block": "Default Authorization Settings",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **10dae51f-b6af-4016-8d66-8c2a99b929b3**.\n\nThe recommended value is **'2af84b1e-32c8-42b7-82bc-daa82404023b'** for **policies/authorizationPolicy**\n",
        "TestDescription": "Represents role templateId for the role that should be granted to guest user.\n\nCISA SCuBA 2.18: Guest users SHOULD have limited access to Azure AD directory objects.\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authorizationPolicy\n.guestUserRoleId = '2af84b1e-32c8-42b7-82bc-daa82404023b'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [authorizationPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/AllowlistPolicyBlade)\n\n"
      }
    },
    {
      "Name": "EIDSCA.AP08: Default Authorization Settings - User consent policy assigned for applications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AP08",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AP08"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authorizationPolicy\"\n         .permissionGrantPolicyIdsAssignedToDefaultUserRole[2] = 'ManagePermissionGrantsForSelf.microsoft-user-default-low'\n      #>\n      Test-MtEidscaAP08 | Should -Be 'ManagePermissionGrantsForSelf.microsoft-user-default-low'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, but they were different.\nExpected length: 56\nActual length:   89\nStrings differ at index 25.\nExpected: 'ManagePermissionGrantsForSelf.microsoft-user-default-low'\nBut was:  'ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-chat'\n           -------------------------^"
      ],
      "Block": "Default Authorization Settings",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-chat**.\n\nThe recommended value is **'ManagePermissionGrantsForSelf.microsoft-user-default-low'** for **policies/authorizationPolicy**\n",
        "TestDescription": "Defines if user consent to apps is allowed, and if it is, which app consent policy (permissionGrantPolicy) governs the permissions.\n\nMicrosoft recommends to allow to user consent for apps from verified publisher for selected permissions. CISA SCuBA 2.7 defines that all Non-Admin Users SHALL Be Prevented From Providing Consent To Third-Party Applications.\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authorizationPolicy\n.permissionGrantPolicyIdsAssignedToDefaultUserRole[2] = 'ManagePermissionGrantsForSelf.microsoft-user-default-low'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [authorizationPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/UserSettings)\n\n"
      }
    },
    {
      "Name": "EIDSCA.AP09: Default Authorization Settings - Risk-based step-up consent.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AP09",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AP09"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authorizationPolicy\"\n         .allowUserConsentForRiskyApps = 'false'\n      #>\n      Test-MtEidscaAP09 | Should -Be 'false'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Authorization Settings",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **False**.\n\nThe recommended value is **'false'** for **policies/authorizationPolicy**\n",
        "TestDescription": "Indicates whether user consent for risky apps is allowed. For example, consent requests for newly registered multi-tenant apps that are not publisher verified and require non-basic permissions are considered risky.\n\n[Configure risk-based step-up consent - Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/manage-apps/configure-risk-based-step-up-consent)\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authorizationPolicy\n.allowUserConsentForRiskyApps = 'false'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [authorizationPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AP10: Default Authorization Settings - Default User Role Permissions - Allowed to create Apps.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AP10",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AP10"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authorizationPolicy\"\n         .defaultUserRolePermissions.allowedToCreateApps = 'false'\n      #>\n      Test-MtEidscaAP10 | Should -Be 'false'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Authorization Settings",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **False**.\n\nThe recommended value is **'false'** for **policies/authorizationPolicy**\n",
        "TestDescription": "Controls if non-admin users may register custom-developed applications for use within this directory.\n\nCISA SCuBA 2.6: Only Administrators SHALL Be Allowed To Register Third-Party Applications\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authorizationPolicy\n.defaultUserRolePermissions.allowedToCreateApps = 'false'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [authorizationPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/UserSettings)\n\n"
      }
    },
    {
      "Name": "EIDSCA.AP14: Default Authorization Settings - Default User Role Permissions - Allowed to read other users.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AP14",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AP14"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authorizationPolicy\"\n         .defaultUserRolePermissions.allowedToReadOtherUsers = 'true'\n      #>\n      Test-MtEidscaAP14 | Should -Be 'true'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Authorization Settings",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'true'** for **policies/authorizationPolicy**\n",
        "TestDescription": "Prevents all non-admins from reading user information from the directory. This flag doesn't prevent reading user information in other Microsoft services like Exchange Online.\n\nRestrict this default permissions for members have huge impact on collaboration features and user lookup.\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authorizationPolicy\n.defaultUserRolePermissions.allowedToReadOtherUsers = 'true'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [authorizationPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AT01: Authentication Method - Temporary Access Pass - State.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AT01",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AT01"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\"\n         .state = 'enabled'\n      #>\n      Test-MtEidscaAT01 | Should -Be 'enabled'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Temporary Access Pass",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')**\n",
        "TestDescription": "Whether the Temporary Access Pass is enabled in the tenant.\n\nUse Temporary Access Pass for secure onboarding users (initial password replacement) and enforce MFA for registering security information in Conditional Access Policy.\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\n.state = 'enabled'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [temporaryAccessPassAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/temporaryaccesspassauthenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AT02: Authentication Method - Temporary Access Pass - One-time.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AT02",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AT02"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\"\n         .isUsableOnce = 'false'\n      #>\n      Test-MtEidscaAT02 | Should -Be 'false'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Temporary Access Pass",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **False**.\n\nThe recommended value is **'false'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')**\n",
        "TestDescription": "Determines whether the pass is limited to a one-time use.\n\nAvoid to allow reusable passes and restrict usage to one-time use (if applicable)\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\n.isUsableOnce = 'false'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [temporaryAccessPassAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/temporaryaccesspassauthenticationmethodconfiguration)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.AV01: Authentication Method - Voice call - State.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.AV01",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AV01"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')\"\n         .state = 'disabled'\n      #>\n      Test-MtEidscaAV01 | Should -Be 'disabled'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Voice call",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'disabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')**\n",
        "TestDescription": "Whether the Voice call is enabled in the tenant.\n\nChoose authentication methods with number matching (Authenticator) \n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')\n.state = 'disabled'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.CP01: Default Settings - Consent Policy Settings - Group owner consent for apps accessing data.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.CP01",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.CP01"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/settings\"\n         .values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value = 'False'\n      #>\n      Test-MtEidscaCP01 | Should -Be 'False'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, but they were different.\nExpected length: 5\nActual length:   0\nStrings differ at index 0.\nExpected: 'False'\nBut was:  ''\n           ^"
      ],
      "Block": "Default Settings - Consent Policy Settings",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as ****.\n\nThe recommended value is **'False'** for **settings**\n",
        "TestDescription": "Group and team owners can authorize applications, such as applications published by third-party vendors, to access your organization's data associated with a group. For example, a team owner in Microsoft Teams can allow an app to read all Teams messages in the team, or list the basic profile of a group's members.\n\nCISA SCuBA 2.7: Non-Admin Users SHALL Be Prevented From Providing Consent To Third-Party Applications.\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/settings\n.values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value = 'False'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/UserSettings)\n\n"
      }
    },
    {
      "Name": "EIDSCA.CP03: Default Settings - Consent Policy Settings - Block user consent for risky apps.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.CP03",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.CP03"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/settings\"\n         .values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value = 'true'\n      #>\n      Test-MtEidscaCP03 | Should -Be 'true'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Settings - Consent Policy Settings",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'true'** for **settings**\n",
        "TestDescription": "Defines whether user consent will be blocked when a risky request is detected\n\n[Configure risk-based step-up consent - Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/manage-apps/configure-risk-based-step-up-consent)\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/settings\n.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value = 'true'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.CP04: Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to???.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.CP04",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.CP04"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/settings\"\n         .values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value = 'true'\n      #>\n      Test-MtEidscaCP04 | Should -Be 'true'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, but they were different.\nExpected length: 4\nActual length:   5\nStrings differ at index 0.\nExpected: 'true'\nBut was:  'false'\n           ^"
      ],
      "Block": "Default Settings - Consent Policy Settings",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **false**.\n\nThe recommended value is **'true'** for **settings**\n",
        "TestDescription": "If this option is set to enabled, then users request admin consent to any app that requires access to data they do not have the permission to grant. If this option is set to disabled, then users must contact their admin to request to consent in order to use the apps they need.\n\nCISA SCuBA 2.7: Non-Admin Users SHALL Be Prevented From Providing Consent To Third-Party Applications.\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/settings\n.values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value = 'true'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/AdminConsentSettings)\n\n"
      }
    },
    {
      "Name": "EIDSCA.CR01: Consent Framework - Admin Consent Request - Users can request admin consent to apps they are unable to consent to.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.CR01",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.CR01"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy\"\n         .isEnabled = 'true'\n      #>\n      Test-MtEidscaCR01 | Should -Be 'true'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'true', but got $false."
      ],
      "Block": "Consent Framework - Admin Consent Request",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **False**.\n\nThe recommended value is **'true'** for **policies/adminConsentRequestPolicy**\n",
        "TestDescription": "Defines if admin consent request feature is enabled or disabled\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/adminConsentRequestPolicy\n.isEnabled = 'true'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/adminConsentRequestPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [adminConsentRequestPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/adminconsentrequestpolicy)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/AdminConsentSettings)\n\n"
      }
    },
    {
      "Name": "EIDSCA.CR02: Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests???.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.CR02",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.CR02"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy\"\n         .notifyReviewers = 'true'\n      #>\n      Test-MtEidscaCR02 | Should -Be 'true'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'true', but got $false."
      ],
      "Block": "Consent Framework - Admin Consent Request",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **False**.\n\nThe recommended value is **'true'** for **policies/adminConsentRequestPolicy**\n",
        "TestDescription": "Specifies whether reviewers will receive notifications\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/adminConsentRequestPolicy\n.notifyReviewers = 'true'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/adminConsentRequestPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [adminConsentRequestPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/adminconsentrequestpolicy)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/AdminConsentSettings)\n\n"
      }
    },
    {
      "Name": "EIDSCA.CR03: Consent Framework - Admin Consent Request - Reviewers will receive email notifications when admin consent requests are about to expire???.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.CR03",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.CR03"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy\"\n         .notifyReviewers = 'true'\n      #>\n      Test-MtEidscaCR03 | Should -Be 'true'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'true', but got $false."
      ],
      "Block": "Consent Framework - Admin Consent Request",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **False**.\n\nThe recommended value is **'true'** for **policies/adminConsentRequestPolicy**\n",
        "TestDescription": "Specifies whether reviewers will receive reminder emails\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/adminConsentRequestPolicy\n.notifyReviewers = 'true'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/adminConsentRequestPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [adminConsentRequestPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/adminconsentrequestpolicy)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/AdminConsentSettings)\n\n"
      }
    },
    {
      "Name": "EIDSCA.CR04: Consent Framework - Admin Consent Request - Consent request duration (days)???.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.CR04",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.CR04"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy\"\n         .requestDurationInDays = '30'\n      #>\n      Test-MtEidscaCR04 | Should -Be '30'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected '30', but got 0."
      ],
      "Block": "Consent Framework - Admin Consent Request",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **0**.\n\nThe recommended value is **'30'** for **policies/adminConsentRequestPolicy**\n",
        "TestDescription": "Specifies the duration the request is active before it automatically expires if no decision is applied\n\n\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/policies/adminConsentRequestPolicy\n.requestDurationInDays = '30'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/adminConsentRequestPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [adminConsentRequestPolicy resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/adminconsentrequestpolicy)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/AdminConsentSettings)\n\n"
      }
    },
    {
      "Name": "EIDSCA.PR01: Default Settings - Password Rule Settings - Password Protection - Mode.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.PR01",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.PR01"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/settings\"\n         .values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value = 'Enforce'\n      #>\n      Test-MtEidscaPR01 | Should -Be 'Enforce'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, but they were different.\nExpected length: 7\nActual length:   5\nStrings differ at index 0.\nExpected: 'Enforce'\nBut was:  'Audit'\n           ^"
      ],
      "Block": "Default Settings - Password Rule Settings",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as **Audit**.\n\nThe recommended value is **'Enforce'** for **settings**\n",
        "TestDescription": "If set to Enforce, users will be prevented from setting banned passwords and the attempt will be logged. If set to Audit, the attempt will only be logged.\n\n[Microsoft Entra Password Protection - Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/authentication/concept-password-ban-bad-on-premises)\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/settings\n.values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value = 'Enforce'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)\n\n"
      }
    },
    {
      "Name": "EIDSCA.PR02: Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.PR02",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.PR02"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/settings\"\n         .values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value = 'True'\n      #>\n      Test-MtEidscaPR02 | Should -Be 'True'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Settings - Password Rule Settings",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'True'** for **settings**\n",
        "TestDescription": "If set to Yes, password protection is turned on for Active Directory domain controllers when the appropriate agent is installed.\n\n[Azure identity & access security best practices - Microsoft Learn](https://learn.microsoft.com/en-us/azure/security/fundamentals/identity-management-best-practices#enable-password-management)\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/settings\n.values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value = 'True'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)\n\n"
      }
    },
    {
      "Name": "EIDSCA.PR03: Default Settings - Password Rule Settings - Enforce custom list.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.PR03",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.PR03"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/settings\"\n         .values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value = 'True'\n      #>\n      Test-MtEidscaPR03 | Should -Be 'True'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Settings - Password Rule Settings",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'True'** for **settings**\n",
        "TestDescription": "When enabled, the words in the list below are used in the banned password system to prevent easy-to-guess passwords.\n\n[Password protection in Microsoft Entra ID - Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/authentication/concept-password-ban-bad#global-banned-password-list)\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/settings\n.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value = 'True'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)\n\n"
      }
    },
    {
      "Name": "EIDSCA.PR05: Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.PR05",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.PR05"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/settings\"\n         .values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value = '60'\n      #>\n      Test-MtEidscaPR05 | Should -Be '60'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Settings - Password Rule Settings",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'60'** for **settings**\n",
        "TestDescription": "The minimum length in seconds of each lockout. If an account locks repeatedly, this duration increases.\n\n[Prevent attacks using smart lockout - Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/authentication/howto-password-smart-lockout)\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/settings\n.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value = '60'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)\n\n"
      }
    },
    {
      "Name": "EIDSCA.PR06: Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.PR06",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.PR06"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/settings\"\n         .values | where-object name -eq 'LockoutThreshold' | select-object -expand value = '10'\n      #>\n      Test-MtEidscaPR06 | Should -Be '10'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Settings - Password Rule Settings",
      "ResultDetail": {
        "TestResult": "\nWell done. Your tenant has the recommended value of **'10'** for **settings**\n",
        "TestDescription": "How many failed sign-ins are allowed on an account before its first lockout. If the first sign-in after a lockout also fails, the account locks out again.\n\n[Prevent attacks using smart lockout - Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/authentication/howto-password-smart-lockout)\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/settings\n.values | where-object name -eq 'LockoutThreshold' | select-object -expand value = '10'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)\n- [View in Microsoft Entra admin center](https://portal.azure.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)\n\n"
      }
    },
    {
      "Name": "EIDSCA.ST08: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.ST08",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.ST08"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/settings\"\n         .values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value = 'false'\n      #>\n      Test-MtEidscaST08 | Should -Be 'false'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'false', but got $null."
      ],
      "Block": "Default Settings - Classification and M365 Groups",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as ****.\n\nThe recommended value is **'false'** for **settings**\n",
        "TestDescription": "Indicating whether or not a guest user can be an owner of groups\n\nCISA SCuBA 2.18: Guest users SHOULD have limited access to Azure AD directory objects\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/settings\n.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value = 'false'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)\n\n\n"
      }
    },
    {
      "Name": "EIDSCA.ST09: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.ST09",
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.ST09"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n      <#\n         Check if \"https://graph.microsoft.com/beta/settings\"\n         .values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value = 'True'\n      #>\n      Test-MtEidscaST09 | Should -Be 'True'\n   ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'True', but got $null."
      ],
      "Block": "Default Settings - Classification and M365 Groups",
      "ResultDetail": {
        "TestResult": "\nYour tenant is configured as ****.\n\nThe recommended value is **'True'** for **settings**\n",
        "TestDescription": "Indicating whether or not a guest user can have access to Microsoft 365 groups content. This setting does not require an Azure Active Directory Premium P1 license.\n\nManages if guest accounts can access resources through Microsoft 365 Group membership and could break collaboration if you disable it.\n\n#### Test details\n```\nhttps://graph.microsoft.com/beta/settings\n.values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value = 'True'\n```\n\n#### Related links\n\n- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)\n- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)\n\n\n"
      }
    },
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
      "Name": "MT.1002: App management restrictions on applications and service principals is configured and enabled.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1002",
      "Tag": [
        "App",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtAppManagementPolicyEnabled | Should -Be $true -Because \"an app policy for workload identities should be defined to enforce strong credentials instead of passwords and a maximum expiry period (e.g. credential should be renewed every six months)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-AppManagementPolicies.Tests.ps1",
      "ErrorRecord": [
        "Expected $true, because an app policy for workload identities should be defined to enforce strong credentials instead of passwords and a maximum expiry period (e.g. credential should be renewed every six months), but got $false."
      ],
      "Block": "App Management Policies",
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
        "TestResult": "\nThese conditional access policies don't have the emergency access account or group excluded:\n\n  - [MFA - All users](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/474ddef4-5620-4e7a-8976-6e9b095b2675)\n  - [SPO](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/2fb9f832-9af7-4ad9-8468-30035ad62a7e)\n  - [ACSC - L2](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/dd4e567d-47ae-4d1f-acaa-6d4ff1cd14e4)\n  - [O365](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/31181d5c-dd6b-4679-aea2-e6f0ad30757a)\n  - [Register device](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/c9d0080b-86e0-464a-9e25-8ca4e186fb5a)\n  - [nestedgroup count](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/9e6a9793-e3ae-451e-9011-0a9bbbcfdc9b)\n  - [AppProtect](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/5a5ee06f-4164-4112-9960-fe0903c2ccee)\n  - [MFA CA Policy](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/e589544c-0c92-432e-86ae-4e4ef103eac8)\n  - [Force Password Change](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/5848211d-96f2-40ae-92a4-af1aa8f48572)\n  - [TestEntraExporterNullCA Issue](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/a5c10ada-7660-468b-b8ba-76deb53686fc)\n  - [No persistence](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/ff9b569d-329f-4d8b-a984-b8da833e19ea)\n  - [Require multifactor authentication for Microsoft admin portals](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/db73ea6f-4017-4b04-97e9-c5f6fedec0d0)\n  - [j-test admin](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/6c0ef46a-3b58-43a9-b451-7464a16d91d7)\n  - [Device compliancy](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/206c9071-89d7-4b57-adaf-87f78a4bd7f5)\n  - [Device compliance #1](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/2965e1d4-6146-41a5-abae-5219abf7d68f)\n  - [Guest 10 hr MFA](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/bcc1a12e-c68d-419e-a6c4-6d4bdfa8bfc8)\n  - [Guest-Meferna-Woodgrove-PhishingResistantAuthStrength](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/0f0a0c1c-41b0-4c18-ae20-d02492d03737)\n  - [Block Device Code](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/db2153a1-40a2-457f-917c-c280b204b5cd)\n",
        "TestDescription": "It is recommended to have at least one emergency/break glass account or account group excluded from all conditional access policies.\nThis allows for emergency access to the tenant in case of a misconfiguration or other issues.\n\nSee [Manage emergency access accounts in Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access)\n\n"
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
    },
    {
      "Name": "MT.1022: All users covered by a P1 license are utilizing this license.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1022",
      "Tag": [],
      "Result": "Failed",
      "ScriptBlock": "\n            $LicenseReport = Test-MtCaLicenseUtilization -License \"P1\"\n            $LicenseReport.TotalLicensesUtilized | Should -BeGreaterOrEqual $LicenseReport.EntitledLicenseCount -Because \"this is the maximium number of user that can utilize a P1 license\"\n        ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "A positional parameter cannot be found that accepts argument 'Entitled P1 license count: 25 & '."
      ],
      "Block": "License utilization",
      "ResultDetail": null
    },
    {
      "Name": "MT.1023: All users covered by a P2 license are utilizing this license.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1023",
      "Tag": [],
      "Result": "Failed",
      "ScriptBlock": "\n            $LicenseReport = Test-MtCaLicenseUtilization -License \"P2\"\n            $LicenseReport.TotalLicensesUtilized | Should -BeGreaterOrEqual $LicenseReport.EntitledLicenseCount -Because \"this is the maximium number of user that can utilize a P2 license\"\n        ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [
        "A positional parameter cannot be found that accepts argument 'Entitled P1 license count: 25 & '."
      ],
      "Block": "License utilization",
      "ResultDetail": null
    },
    {
      "Name": "MT.1021: Security Defaults are enabled.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1021",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "Skipped",
      "ScriptBlock": "\n        $SecurityDefaults = Invoke-MgGraphRequest -Uri \"https://graph.microsoft.com/beta/policies/identitySecurityDefaultsEnforcementPolicy\" | Select-Object -ExpandProperty isEnabled\n        $SecurityDefaults | Should -Be $true -Because \"Security Defaults are not enabled\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Security Defaults",
      "ResultDetail": null
    }
  ],
  "Blocks": [
    {
      "Name": "Default Authorization Settings",
      "Result": "Passed",
      "FailedCount": 5,
      "PassedCount": 4,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 9,
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AP01"
      ]
    },
    {
      "Name": "Default Settings - Consent Policy Settings",
      "Result": "Failed",
      "FailedCount": 2,
      "PassedCount": 1,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 3,
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.CP01"
      ]
    },
    {
      "Name": "Default Settings - Password Rule Settings",
      "Result": "Failed",
      "FailedCount": 1,
      "PassedCount": 4,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 5,
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.PR01"
      ]
    },
    {
      "Name": "Default Settings - Classification and M365 Groups",
      "Result": "Failed",
      "FailedCount": 2,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 2,
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.ST08"
      ]
    },
    {
      "Name": "Authentication Method - General Settings",
      "Result": "Failed",
      "FailedCount": 2,
      "PassedCount": 1,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 3,
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AG01"
      ]
    },
    {
      "Name": "Authentication Method - Microsoft Authenticator",
      "Result": "Passed",
      "FailedCount": 0,
      "PassedCount": 8,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 8,
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AM01"
      ]
    },
    {
      "Name": "Authentication Method - FIDO2 security key",
      "Result": "Passed",
      "FailedCount": 0,
      "PassedCount": 4,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 4,
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AF01"
      ]
    },
    {
      "Name": "Authentication Method - Temporary Access Pass",
      "Result": "Passed",
      "FailedCount": 0,
      "PassedCount": 2,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 2,
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AT01"
      ]
    },
    {
      "Name": "Authentication Method - Voice call",
      "Result": "Passed",
      "FailedCount": 0,
      "PassedCount": 1,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 1,
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.AV01"
      ]
    },
    {
      "Name": "Consent Framework - Admin Consent Request",
      "Result": "Failed",
      "FailedCount": 4,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 4,
      "Tag": [
        "EIDSCA",
        "Security",
        "All",
        "EIDSCA.CR01"
      ]
    },
    {
      "Name": "App Management Policies",
      "Result": "Failed",
      "FailedCount": 1,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 1,
      "Tag": [
        "App",
        "Security",
        "All"
      ]
    },
    {
      "Name": "Conditional Access Baseline Policies",
      "Result": "Failed",
      "FailedCount": 16,
      "PassedCount": 5,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 21,
      "Tag": [
        "CA",
        "Security",
        "All"
      ]
    },
    {
      "Name": "Security Defaults",
      "Result": "Skipped",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 1,
      "NotRunCount": 0,
      "TotalCount": 1,
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
