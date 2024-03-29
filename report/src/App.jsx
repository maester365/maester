import './App.css'
import TestResultsTable from './components/TestResultsTable';
import { Flex, Divider, Grid, Text, Badge } from "@tremor/react";
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
  "ExecutedAt": "2024-03-30T01:09:47.304111+11:00",
  "TenantId": "0817c655-a853-4d8f-9723-3a333b5b9235",
  "TenantName": "Pora",
  "Account": "merill@elapora.com",
  "Tests": [
    {
      "Name": "EIDSCA.AF01: Authentication Method - FIDO2 security key - State.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.state",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/state should be 'enabled'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - FIDO2 security key",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AF02: Authentication Method - FIDO2 security key - Allow self-service set up.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.isSelfServiceRegistrationAllowed",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.isSelfServiceRegistrationAllowed | Should -Be 'true' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/isSelfServiceRegistrationAllowed should be 'true'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - FIDO2 security key",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AF03: Authentication Method - FIDO2 security key - Enforce attestation.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.isAttestationEnforced",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.isAttestationEnforced | Should -Be 'true' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/isAttestationEnforced should be 'true'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - FIDO2 security key",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AF06: Authentication Method - FIDO2 security key - Restrict specific keys.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.keyRestrictions.enforcementType",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.keyRestrictions.enforcementType | Should -Be 'block' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.enforcementType should be 'block'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - FIDO2 security key",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AG01: Authentication Method - General Settings - Manage migration.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.policyMigrationState",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.policyMigrationState | Should -Be 'migrationComplete' -Because \"policies/authenticationMethodsPolicy/policyMigrationState should be 'migrationComplete'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/policyMigrationState should be 'migrationComplete', but they were different.\nExpected length: 17\nActual length:   19\nStrings differ at index 9.\nExpected: 'migrationComplete'\nBut was:  'migrationInProgress'\n           ---------^"
      ],
      "Block": "Authentication Method - General Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AG02: Authentication Method - General Settings - Report suspicious activity - State.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsState",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.reportSuspiciousActivitySettings.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.state should be 'enabled'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.state should be 'enabled', but they were different.\nString lengths are both 7.\nStrings differ at index 0.\nExpected: 'enabled'\nBut was:  'default'\n           ^"
      ],
      "Block": "Authentication Method - General Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AG03: Authentication Method - General Settings - Report suspicious activity - Included users/groups.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsIncluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.reportSuspiciousActivitySettings.includeTarget.id | Should -Be 'all_users' -Because \"policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.includeTarget.id should be 'all_users'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - General Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AM01: Authentication Method - Microsoft Authenticator - State.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.state",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/state should be 'enabled'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AM02: Authentication Method - Microsoft Authenticator - Allow use of Microsoft Authenticator OTP.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.isSoftwareOathEnabled",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/state should be 'enabled'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AM03: Authentication Method - Microsoft Authenticator - Require number matching for push notifications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.numberMatchingRequiredState",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.numberMatchingRequiredState.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.state should be 'enabled'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AM04: Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.numberMatchingRequiredStateIncluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.numberMatchingRequiredState.includeTarget.id | Should -Be 'all_users' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.includeTarget.id should be 'all_users'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AM06: Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.displayAppInformationRequiredState",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayAppInformationRequiredState.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.state should be 'enabled'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AM07: Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.displayAppInformationRequiredStateIncluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayAppInformationRequiredState.includeTarget.id | Should -Be 'all_users' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.includeTarget.id should be 'all_users'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AM09: Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.displayLocationInformationRequiredState",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayLocationInformationRequiredState.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.state should be 'enabled'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AM10: Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.displayLocationInformationRequiredStateIncluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayLocationInformationRequiredState.includeTarget.id | Should -Be 'all_users' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.includeTarget.id should be 'all_users'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AP01: Default Authorization Settings - Enabled Self service password reset.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowedToUseSSPR",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToUseSSPR | Should -Be 'true' -Because \"policies/authorizationPolicy/allowedToUseSSPR should be 'true'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Authorization Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AP04: Default Authorization Settings - Guest invite restrictions.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowInvitesFrom",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowInvitesFrom | Should -Be 'adminsAndGuestInviters' -Because \"policies/authorizationPolicy/allowInvitesFrom should be 'adminsAndGuestInviters'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authorizationPolicy/allowInvitesFrom should be 'adminsAndGuestInviters', but they were different.\nExpected length: 22\nActual length:   8\nStrings differ at index 0.\nExpected: 'adminsAndGuestInviters'\nBut was:  'everyone'\n           ^"
      ],
      "Block": "Default Authorization Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AP05: Default Authorization Settings - Sign-up for email based subscription.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowedToSignUpEmailBasedSubscriptions",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToSignUpEmailBasedSubscriptions | Should -Be 'false' -Because \"policies/authorizationPolicy/allowedToSignUpEmailBasedSubscriptions should be 'false'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'false', because policies/authorizationPolicy/allowedToSignUpEmailBasedSubscriptions should be 'false', but got $true."
      ],
      "Block": "Default Authorization Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AP06: Default Authorization Settings - User can joint the tenant by email validation.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowEmailVerifiedUsersToJoinOrganization",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowEmailVerifiedUsersToJoinOrganization | Should -Be 'false' -Because \"policies/authorizationPolicy/allowEmailVerifiedUsersToJoinOrganization should be 'false'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'false', because policies/authorizationPolicy/allowEmailVerifiedUsersToJoinOrganization should be 'false', but got $true."
      ],
      "Block": "Default Authorization Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AP07: Default Authorization Settings - Guest user access.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.guestUserRoleId",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.guestUserRoleId | Should -Be '2af84b1e-32c8-42b7-82bc-daa82404023b' -Because \"policies/authorizationPolicy/guestUserRoleId should be '2af84b1e-32c8-42b7-82bc-daa82404023b'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authorizationPolicy/guestUserRoleId should be '2af84b1e-32c8-42b7-82bc-daa82404023b', but they were different.\nString lengths are both 36.\nStrings differ at index 0.\nExpected: '2af84b1e-32c8-42b7-82bc-daa82404023b'\nBut was:  '10dae51f-b6af-4016-8d66-8c2a99b929b3'\n           ^"
      ],
      "Block": "Default Authorization Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AP08: Default Authorization Settings - User consent policy assigned for applications.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.permissionGrantPolicyIdsAssignedToDefaultUserRole",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.permissionGrantPolicyIdsAssignedToDefaultUserRole[2] | Should -Be 'ManagePermissionGrantsForSelf.microsoft-user-default-low' -Because \"policies/authorizationPolicy/permissionGrantPolicyIdsAssignedToDefaultUserRole[2] should be 'ManagePermissionGrantsForSelf.microsoft-user-default-low'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authorizationPolicy/permissionGrantPolicyIdsAssignedToDefaultUserRole[2] should be 'ManagePermissionGrantsForSelf.microsoft-user-default-low', but they were different.\nExpected length: 56\nActual length:   89\nStrings differ at index 25.\nExpected: 'ManagePermissionGrantsForSelf.microsoft-user-default-low'\nBut was:  'ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-chat'\n           -------------------------^"
      ],
      "Block": "Default Authorization Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AP09: Default Authorization Settings - Risk-based step-up consent.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowUserConsentForRiskyApps",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowUserConsentForRiskyApps | Should -Be 'false' -Because \"policies/authorizationPolicy/allowUserConsentForRiskyApps should be 'false'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Authorization Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AP10: Default Authorization Settings - Default User Role Permissions - Allowed to create Apps.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowedToCreateApps",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.defaultUserRolePermissions.allowedToCreateApps | Should -Be 'false' -Because \"policies/authorizationPolicy/defaultUserRolePermissions.allowedToCreateApps should be 'false'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Authorization Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AP14: Default Authorization Settings - Default User Role Permissions - Allowed to read other users.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowedToReadOtherUsers",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.defaultUserRolePermissions.allowedToReadOtherUsers | Should -Be 'true' -Because \"policies/authorizationPolicy/defaultUserRolePermissions.allowedToReadOtherUsers should be 'true'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Authorization Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AT01: Authentication Method - Temporary Access Pass - State.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.state",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/state should be 'enabled'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Temporary Access Pass",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AT02: Authentication Method - Temporary Access Pass - One-time.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.isUsableOnce",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.isUsableOnce | Should -Be 'false' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/isUsableOnce should be 'false'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Temporary Access Pass",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.AV01: Authentication Method - Voice call - State.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.state",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')\" -ApiVersion beta\n        $result.state | Should -Be 'disabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/state should be 'disabled'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Voice call",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.CP01: Default Settings - Consent Policy Settings - Group owner consent for apps accessing data.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.settings.EnableGroupSpecificConsent",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value | Should -Be 'False' -Because \"settings/values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value should be 'False'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because settings/values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value should be 'False', but they were different.\nExpected length: 5\nActual length:   0\nStrings differ at index 0.\nExpected: 'False'\nBut was:  ''\n           ^"
      ],
      "Block": "Default Settings - Consent Policy Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.CP03: Default Settings - Consent Policy Settings - Block user consent for risky apps.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.settings.BlockUserConsentForRiskyApps",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value | Should -Be 'true' -Because \"settings/values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value should be 'true'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Settings - Consent Policy Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.CP04: Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to???.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.settings.EnableAdminConsentRequests",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value | Should -Be 'true' -Because \"settings/values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value should be 'true'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because settings/values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value should be 'true', but they were different.\nExpected length: 4\nActual length:   5\nStrings differ at index 0.\nExpected: 'true'\nBut was:  'false'\n           ^"
      ],
      "Block": "Default Settings - Consent Policy Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.CR01: Consent Framework - Admin Consent Request - Users can request admin consent to apps they are unable to consent to.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.servicePrincipalCreationPolicies.isEnabled",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.isEnabled | Should -Be 'true' -Because \"policies/adminConsentRequestPolicy/isEnabled should be 'true'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'true', because policies/adminConsentRequestPolicy/isEnabled should be 'true', but got $false."
      ],
      "Block": "Consent Framework - Admin Consent Request",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.CR02: Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests???.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.servicePrincipalCreationPolicies.notifyReviewers",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.notifyReviewers | Should -Be 'true' -Because \"policies/adminConsentRequestPolicy/notifyReviewers should be 'true'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'true', because policies/adminConsentRequestPolicy/notifyReviewers should be 'true', but got $false."
      ],
      "Block": "Consent Framework - Admin Consent Request",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.CR03: Consent Framework - Admin Consent Request - Reviewers will receive email notifications when admin consent requests are about to expire???.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.servicePrincipalCreationPolicies.notifyReviewers",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.notifyReviewers | Should -Be 'true' -Because \"policies/adminConsentRequestPolicy/notifyReviewers should be 'true'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'true', because policies/adminConsentRequestPolicy/notifyReviewers should be 'true', but got $false."
      ],
      "Block": "Consent Framework - Admin Consent Request",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.CR04: Consent Framework - Admin Consent Request - Consent request duration (days)???.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.servicePrincipalCreationPolicies.requestDurationInDays",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.requestDurationInDays | Should -Be '30' -Because \"policies/adminConsentRequestPolicy/requestDurationInDays should be '30'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected '30', because policies/adminConsentRequestPolicy/requestDurationInDays should be '30', but got 0."
      ],
      "Block": "Consent Framework - Admin Consent Request",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.PR01: Default Settings - Password Rule Settings - Password Protection - Mode.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.settings.BannedPasswordCheckOnPremisesMode",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value | Should -Be 'Enforce' -Because \"settings/values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value should be 'Enforce'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because settings/values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value should be 'Enforce', but they were different.\nExpected length: 7\nActual length:   5\nStrings differ at index 0.\nExpected: 'Enforce'\nBut was:  'Audit'\n           ^"
      ],
      "Block": "Default Settings - Password Rule Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.PR02: Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.settings.EnableBannedPasswordCheckOnPremises",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value | Should -Be 'True' -Because \"settings/values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value should be 'True'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Settings - Password Rule Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.PR03: Default Settings - Password Rule Settings - Enforce custom list.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.settings.EnableBannedPasswordCheck",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value | Should -Be 'True' -Because \"settings/values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value should be 'True'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Settings - Password Rule Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.PR05: Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.settings.LockoutDurationInSeconds",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value | Should -Be '60' -Because \"settings/values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value should be '60'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Settings - Password Rule Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.PR06: Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.settings.LockoutThreshold",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values | where-object name -eq 'LockoutThreshold' | select-object -expand value | Should -Be '10' -Because \"settings/values | where-object name -eq 'LockoutThreshold' | select-object -expand value should be '10'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Settings - Password Rule Settings",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.ST08: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.settings.AllowGuestsToBeGroupOwner",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value | Should -Be 'false' -Because \"settings/values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value should be 'false'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'false', because settings/values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value should be 'false', but got $null."
      ],
      "Block": "Default Settings - Classification and M365 Groups",
      "ResultDetail": null
    },
    {
      "Name": "EIDSCA.ST09: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content.",
      "HelpUrl": "https://maester.dev/docs/tests/EIDSCA.settings.AllowGuestsToAccessGroups",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value | Should -Be 'True' -Because \"settings/values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value should be 'True'\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'True', because settings/values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value should be 'True', but got $null."
      ],
      "Block": "Default Settings - Classification and M365 Groups",
      "ResultDetail": null
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
        "TestResult": "These conditional access policies don't have the emergency access account or group excluded:\n\n  - [ACSC - L2](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [AppProtect](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [Block Device Code](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [Device compliance #1](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [Device compliancy](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [Force Password Change](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [Guest 10 hr MFA](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [Guest-Meferna-Woodgrove-PhishingResistantAuthStrength](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [j-test admin](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [MFA - All users](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [MFA CA Policy](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [nestedgroup count](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [No persistence](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [O365](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [Register device](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [Require multifactor authentication for Microsoft admin portals](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [SPO](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n  - [TestEntraExporterNullCA Issue](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)\n",
        "TestDescription": "\nIt is recommended to have at least one emergency/break glass account or account group excluded from all conditional access policies.\nThis allows for emergency access to the tenant in case of a misconfiguration or other issues.\n\nSee [Manage emergency access accounts in Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access)"
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
      "Result": "Failed",
      "FailedCount": 5,
      "PassedCount": 4,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 9,
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
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
        "All"
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
        "All"
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
        "All"
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
        "All"
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
        "All"
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
        "All"
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
        "All"
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
        "All"
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
        "All"
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
          <Badge className="bg-blue-200" icon={BuildingOfficeIcon}>{getTenantName()}</Badge>
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
