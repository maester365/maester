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
  "FailedCount": 100,
  "PassedCount": 21,
  "SkippedCount": 0,
  "TotalCount": 121,
  "ExecutedAt": "2024-01-20T17:00:59.074646+11:00",
  "TenantId": "0817c655-a853-4d8f-9723-3a333b5b9235",
  "TenantName": "",
  "Account": "merill@elapora.com",
  "Tests": [
    {
      "Name": "ID1002: App management restrictions on applications and service principals is configured and enabled.",
      "HelpUrl": "https://maester.dev/t/ID.1002",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtAppManagementPolicyEnabled | Should -Be $true -Because \"There is no app policy to use secure credentials\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Identity/Test-AppManagementPolicies.Tests.ps1",
      "ErrorRecord": "Expected $true, because There is no app policy to use secure credentials, but got $false.",
      "Duration": "00:00:01.0131214",
      "Block": "[-] App Management Policies"
    },
    {
      "Name": "ID1001: At least one Conditional Access policy is configured with device compliance.",
      "HelpUrl": "https://maester.dev/t/ID.1001",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaDeviceComplianceExists | Should -Be $true -Because \"There is no policy which requires device compliances\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Identity/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:03.8548463",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1003: At least one Conditional Access policy is configured with All Apps.",
      "HelpUrl": "https://maester.dev/t/ID.1003",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists -SkipCheckAllUsers | Should -Be $true -Because \"There is no policy scoped to All Apps\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Identity/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0018950",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1004: At least one Conditional Access policy is configured with All Apps and All Users.",
      "HelpUrl": "https://maester.dev/t/ID.1004",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists | Should -Be $true -Because \"There is no policy scoped to All Apps and All Users\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Identity/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": "Expected $true, because There is no policy scoped to All Apps and All Users, but got $false.",
      "Duration": "00:00:00.0031388",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1005: All Conditional Access policies are configured to exclude at least one emergency account or group.",
      "HelpUrl": "https://maester.dev/t/ID.1005",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaEmergencyAccessExists | Should -Be $true -Because \"There is no emergency access account or group present in all enabled policies\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Identity/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": "Expected $true, because There is no emergency access account or group present in all enabled policies, but got $false.",
      "Duration": "00:00:00.0069257",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1006: At least one Conditional Access policy is configured to require MFA for admins.",
      "HelpUrl": "https://maester.dev/t/ID.1006",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists | Should -Be $true -Because \"There is no policy that requires MFA for admins\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Identity/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": "Expected $true, because There is no policy that requires MFA for admins, but got $false.",
      "Duration": "00:00:00.0028513",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1007: At least one Conditional Access policy is configured to require MFA for all users.",
      "HelpUrl": "https://maester.dev/t/ID.1007",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaMfaForAllUsers | Should -Be $true -Because \"There is no policy that requires MFA for all users\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Identity/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0016465",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "AADSC: Default Authorization Settings - Enabled Self service password reset.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.allowedToUseSSPR",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToUseSSPR | Should -Be 'true' -Because \"policies/authorizationPolicy/allowedToUseSSPR should be 'true' but was $($result.allowedToUseSSPR)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0847478",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - Blocked MSOnline PowerShell access.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.blockMsolPowerShell",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.blockMsolPowerShell | Should -Be '' -Because \"policies/authorizationPolicy/blockMsolPowerShell should be '' but was $($result.blockMsolPowerShell)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authorizationPolicy/blockMsolPowerShell should be '' but was False, but got $false.",
      "Duration": "00:00:00.0033123",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - Enabled .",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.enabledPreviewFeatures",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.enabledPreviewFeatures | Should -Be '' -Because \"policies/authorizationPolicy/enabledPreviewFeatures should be '' but was $($result.enabledPreviewFeatures)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authorizationPolicy/enabledPreviewFeatures should be '' but was, but got $null.",
      "Duration": "00:00:00.0027549",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - Guest invite restrictions.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.allowInvitesFrom",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowInvitesFrom | Should -Be 'adminsAndGuestInviters' -Because \"policies/authorizationPolicy/allowInvitesFrom should be 'adminsAndGuestInviters' but was $($result.allowInvitesFrom)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authorizationPolicy/allowInvitesFrom should be 'adminsAndGuestInviters' but was everyone, but they were different.\nExpected length: 22\nActual length:   8\nStrings differ at index 0.\nExpected: 'adminsAndGuestInviters'\nBut was:  'everyone'\n           ^",
      "Duration": "00:00:00.0062766",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - Sign-up for email based subscription.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.allowedToSignUpEmailBasedSubscriptions",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToSignUpEmailBasedSubscriptions | Should -Be 'false' -Because \"policies/authorizationPolicy/allowedToSignUpEmailBasedSubscriptions should be 'false' but was $($result.allowedToSignUpEmailBasedSubscriptions)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'false', because policies/authorizationPolicy/allowedToSignUpEmailBasedSubscriptions should be 'false' but was True, but got $true.",
      "Duration": "00:00:00.0026022",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - User can joint the tenant by email validation.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.allowEmailVerifiedUsersToJoinOrganization",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowEmailVerifiedUsersToJoinOrganization | Should -Be 'false' -Because \"policies/authorizationPolicy/allowEmailVerifiedUsersToJoinOrganization should be 'false' but was $($result.allowEmailVerifiedUsersToJoinOrganization)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'false', because policies/authorizationPolicy/allowEmailVerifiedUsersToJoinOrganization should be 'false' but was True, but got $true.",
      "Duration": "00:00:00.0025790",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - Guest user access.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.guestUserRoleId",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.guestUserRoleId | Should -Be '2af84b1e-32c8-42b7-82bc-daa82404023b' -Because \"policies/authorizationPolicy/guestUserRoleId should be '2af84b1e-32c8-42b7-82bc-daa82404023b' but was $($result.guestUserRoleId)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authorizationPolicy/guestUserRoleId should be '2af84b1e-32c8-42b7-82bc-daa82404023b' but was 10dae51f-b6af-4016-8d66-8c2a99b929b3, but they were different.\nString lengths are both 36.\nStrings differ at index 0.\nExpected: '2af84b1e-32c8-42b7-82bc-daa82404023b'\nBut was:  '10dae51f-b6af-4016-8d66-8c2a99b929b3'\n           ^",
      "Duration": "00:00:00.0061518",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - User consent policy assigned for applications.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.permissionGrantPolicyIdsAssignedToDefaultUserRole",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.permissionGrantPolicyIdsAssignedToDefaultUserRole | Should -Be 'ManagePermissionGrantsForSelf.microsoft-user-default-low' -Because \"policies/authorizationPolicy/permissionGrantPolicyIdsAssignedToDefaultUserRole should be 'ManagePermissionGrantsForSelf.microsoft-user-default-low' but was $($result.permissionGrantPolicyIdsAssignedToDefaultUserRole)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authorizationPolicy/permissionGrantPolicyIdsAssignedToDefaultUserRole should be 'ManagePermissionGrantsForSelf.microsoft-user-default-low' but was ManagePermissionGrantsForSelf.microsoft-user-default-legacy, but they were different.\nExpected length: 56\nActual length:   59\nStrings differ at index 54.\nExpected: 'ManagePermissionGrantsForSelf.microsoft-user-default-low'\nBut was:  'ManagePermissionGrantsForSelf.microsoft-user-default-legacy'\n           ------------------------------------------------------^",
      "Duration": "00:00:00.0028187",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - Risk-based step-up consent.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.allowUserConsentForRiskyApps",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowUserConsentForRiskyApps | Should -Be 'false' -Because \"policies/authorizationPolicy/allowUserConsentForRiskyApps should be 'false' but was $($result.allowUserConsentForRiskyApps)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0013664",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - Default User Role Permissions - Allowed to create Apps.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.allowedToCreateApps",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.defaultUserRolePermissions.allowedToCreateApps | Should -Be 'false' -Because \"policies/authorizationPolicy/defaultUserRolePermissions.allowedToCreateApps should be 'false' but was $($result.defaultUserRolePermissions.allowedToCreateApps)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0012379",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - Default User Role Permissions - Allowed to create Security Groups.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.allowedToCreateSecurityGroups",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToCreateSecurityGroups | Should -Be '' -Because \"policies/authorizationPolicy/allowedToCreateSecurityGroups should be '' but was $($result.allowedToCreateSecurityGroups)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authorizationPolicy/allowedToCreateSecurityGroups should be '' but was, but got $null.",
      "Duration": "00:00:00.0058266",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - Default User Role Permissions - Allowed to create Tenants.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.allowedToCreateTenants",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToCreateTenants | Should -Be '' -Because \"policies/authorizationPolicy/allowedToCreateTenants should be '' but was $($result.allowedToCreateTenants)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authorizationPolicy/allowedToCreateTenants should be '' but was, but got $null.",
      "Duration": "00:00:00.0027290",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - Default User Role Permissions - Allowed to read BitLocker Keys for Owned Devices.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.allowedToReadBitlockerKeysForOwnedDevice",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToReadBitlockerKeysForOwnedDevice | Should -Be '' -Because \"policies/authorizationPolicy/allowedToReadBitlockerKeysForOwnedDevice should be '' but was $($result.allowedToReadBitlockerKeysForOwnedDevice)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authorizationPolicy/allowedToReadBitlockerKeysForOwnedDevice should be '' but was, but got $null.",
      "Duration": "00:00:00.0026592",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Authorization Settings - Default User Role Permissions - Allowed to read other users.",
      "HelpUrl": "https://maester.dev/t/AADSC.authorizationPolicy.allowedToReadOtherUsers",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToReadOtherUsers | Should -Be 'true' -Because \"policies/authorizationPolicy/allowedToReadOtherUsers should be 'true' but was $($result.allowedToReadOtherUsers)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'true', because policies/authorizationPolicy/allowedToReadOtherUsers should be 'true' but was, but got $null.",
      "Duration": "00:00:00.0025744",
      "Block": "[-] Default Authorization Settings"
    },
    {
      "Name": "AADSC: Default Settings - Consent Policy Settings - Group owner consent for apps accessing data.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.EnableGroupSpecificConsent",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values.EnableGroupSpecificConsent | Should -Be 'False' -Because \"settings/values.EnableGroupSpecificConsent should be 'False' but was $($result.values.EnableGroupSpecificConsent)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'False', because settings/values.EnableGroupSpecificConsent should be 'False' but was, but got @($null, $null, $null, $null, $null, $null, $null, $null, $null, $null).",
      "Duration": "00:00:00.0366710",
      "Block": "[-] Default Settings - Consent Policy Settings"
    },
    {
      "Name": "AADSC: Default Settings - Consent Policy Settings - Group owner consent for apps accessing data - Restricted to selected group owners.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.ConstrainGroupSpecificConsentToMembersOfGroupId",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values.ConstrainGroupSpecificConsentToMembersOfGroupId | Should -Be '' -Because \"settings/values.ConstrainGroupSpecificConsentToMembersOfGroupId should be '' but was $($result.values.ConstrainGroupSpecificConsentToMembersOfGroupId)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/values.ConstrainGroupSpecificConsentToMembersOfGroupId should be '' but was, but got @($null, $null, $null, $null, $null, $null, $null, $null, $null, $null).",
      "Duration": "00:00:00.0035544",
      "Block": "[-] Default Settings - Consent Policy Settings"
    },
    {
      "Name": "AADSC: Default Settings - Consent Policy Settings - Block user consent for risky apps.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.BlockUserConsentForRiskyApps",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values.BlockUserConsentForRiskyApps | Should -Be 'true' -Because \"settings/values.BlockUserConsentForRiskyApps should be 'true' but was $($result.values.BlockUserConsentForRiskyApps)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'true', because settings/values.BlockUserConsentForRiskyApps should be 'true' but was, but got @($null, $null, $null, $null, $null, $null, $null, $null, $null, $null).",
      "Duration": "00:00:00.0067421",
      "Block": "[-] Default Settings - Consent Policy Settings"
    },
    {
      "Name": "AADSC: Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to???.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.EnableAdminConsentRequests",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values.EnableAdminConsentRequests | Should -Be 'true' -Because \"settings/values.EnableAdminConsentRequests should be 'true' but was $($result.values.EnableAdminConsentRequests)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'true', because settings/values.EnableAdminConsentRequests should be 'true' but was, but got @($null, $null, $null, $null, $null, $null, $null, $null, $null, $null).",
      "Duration": "00:00:00.0029952",
      "Block": "[-] Default Settings - Consent Policy Settings"
    },
    {
      "Name": "AADSC: Default Settings - Password Rule Settings - Password Protection - Mode.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.BannedPasswordCheckOnPremisesMode",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.BannedPasswordCheckOnPremisesMode | Should -Be 'Enforce' -Because \"settings/BannedPasswordCheckOnPremisesMode should be 'Enforce' but was $($result.BannedPasswordCheckOnPremisesMode)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'Enforce', because settings/BannedPasswordCheckOnPremisesMode should be 'Enforce' but was, but got @($null, $null).",
      "Duration": "00:00:00.0028059",
      "Block": "[-] Default Settings - Password Rule Settings"
    },
    {
      "Name": "AADSC: Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.EnableBannedPasswordCheckOnPremises",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.EnableBannedPasswordCheckOnPremises | Should -Be 'True' -Because \"settings/EnableBannedPasswordCheckOnPremises should be 'True' but was $($result.EnableBannedPasswordCheckOnPremises)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'True', because settings/EnableBannedPasswordCheckOnPremises should be 'True' but was, but got @($null, $null).",
      "Duration": "00:00:00.0062530",
      "Block": "[-] Default Settings - Password Rule Settings"
    },
    {
      "Name": "AADSC: Default Settings - Password Rule Settings - Enforce custom list.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.EnableBannedPasswordCheck",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.EnableBannedPasswordCheck | Should -Be 'True' -Because \"settings/EnableBannedPasswordCheck should be 'True' but was $($result.EnableBannedPasswordCheck)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'True', because settings/EnableBannedPasswordCheck should be 'True' but was, but got @($null, $null).",
      "Duration": "00:00:00.0028389",
      "Block": "[-] Default Settings - Password Rule Settings"
    },
    {
      "Name": "AADSC: Default Settings - Password Rule Settings - Password Protection - Custom banned password list.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.BannedPasswordList",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.BannedPasswordList | Should -Be '' -Because \"settings/BannedPasswordList should be '' but was $($result.BannedPasswordList)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/BannedPasswordList should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0026922",
      "Block": "[-] Default Settings - Password Rule Settings"
    },
    {
      "Name": "AADSC: Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.LockoutDurationInSeconds",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.LockoutDurationInSeconds | Should -Be '60' -Because \"settings/LockoutDurationInSeconds should be '60' but was $($result.LockoutDurationInSeconds)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected '60', because settings/LockoutDurationInSeconds should be '60' but was, but got @($null, $null).",
      "Duration": "00:00:00.0086355",
      "Block": "[-] Default Settings - Password Rule Settings"
    },
    {
      "Name": "AADSC: Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.LockoutThreshold",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.LockoutThreshold | Should -Be '10' -Because \"settings/LockoutThreshold should be '10' but was $($result.LockoutThreshold)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected '10', because settings/LockoutThreshold should be '10' but was, but got @($null, $null).",
      "Duration": "00:00:00.0030046",
      "Block": "[-] Default Settings - Password Rule Settings"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - Default writeback setting for newly created Microsoft 365 groups.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.NewUnifiedGroupWritebackDefault",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.NewUnifiedGroupWritebackDefault | Should -Be '' -Because \"settings/NewUnifiedGroupWritebackDefault should be '' but was $($result.NewUnifiedGroupWritebackDefault)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/NewUnifiedGroupWritebackDefault should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0029247",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - Microsoft Information Protection (MIP) Sensitivity labels to Microsoft 365 groups.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.EnableMIPLabels",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.EnableMIPLabels | Should -Be '' -Because \"settings/EnableMIPLabels should be '' but was $($result.EnableMIPLabels)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/EnableMIPLabels should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0055506",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - M365 groups naming convention - Custom blocked words list.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.CustomBlockedWordsList",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.CustomBlockedWordsList | Should -Be '' -Because \"settings/CustomBlockedWordsList should be '' but was $($result.CustomBlockedWordsList)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/CustomBlockedWordsList should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0027422",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - M365 groups naming convention - Microsoft Standard List of blocked words (deprecated).",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.EnableMSStandardBlockedWords",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.EnableMSStandardBlockedWords | Should -Be '' -Because \"settings/EnableMSStandardBlockedWords should be '' but was $($result.EnableMSStandardBlockedWords)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/EnableMSStandardBlockedWords should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0027731",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - M365 groups naming convention - Classification descriptions.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.ClassificationDescriptions",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.ClassificationDescriptions | Should -Be '' -Because \"settings/ClassificationDescriptions should be '' but was $($result.ClassificationDescriptions)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/ClassificationDescriptions should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0054848",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - M365 groups naming convention - Default classification.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.DefaultClassification",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.DefaultClassification | Should -Be '' -Because \"settings/DefaultClassification should be '' but was $($result.DefaultClassification)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/DefaultClassification should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0028246",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - M365 groups naming convention - prefix/suffix naming requirement.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.PrefixSuffixNamingRequirement",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.PrefixSuffixNamingRequirement | Should -Be '' -Because \"settings/PrefixSuffixNamingRequirement should be '' but was $($result.PrefixSuffixNamingRequirement)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/PrefixSuffixNamingRequirement should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0026679",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.AllowGuestsToBeGroupOwner",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.AllowGuestsToBeGroupOwner | Should -Be 'false' -Because \"settings/AllowGuestsToBeGroupOwner should be 'false' but was $($result.AllowGuestsToBeGroupOwner)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'false', because settings/AllowGuestsToBeGroupOwner should be 'false' but was, but got @($null, $null).",
      "Duration": "00:00:00.0026779",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.AllowGuestsToAccessGroups",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.AllowGuestsToAccessGroups | Should -Be 'True' -Because \"settings/AllowGuestsToAccessGroups should be 'True' but was $($result.AllowGuestsToAccessGroups)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'True', because settings/AllowGuestsToAccessGroups should be 'True' but was, but got @($null, $null).",
      "Duration": "00:00:00.0056360",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - M365 groups - Guest usage guidelines URL.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.GuestUsageGuidelinesUrl",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.GuestUsageGuidelinesUrl | Should -Be '' -Because \"settings/GuestUsageGuidelinesUrl should be '' but was $($result.GuestUsageGuidelinesUrl)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/GuestUsageGuidelinesUrl should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0027578",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - M365 groups - Enable Group creation for any members.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.EnableGroupCreation",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.EnableGroupCreation | Should -Be '' -Because \"settings/EnableGroupCreation should be '' but was $($result.EnableGroupCreation)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/EnableGroupCreation should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0027621",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - M365 groups - Allow group created for a specific security group.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.GroupCreationAllowedGroupId",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.GroupCreationAllowedGroupId | Should -Be '' -Because \"settings/GroupCreationAllowedGroupId should be '' but was $($result.GroupCreationAllowedGroupId)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/GroupCreationAllowedGroupId should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0060697",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - M365 groups - Allow to add Guests.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.AllowToAddGuests",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.AllowToAddGuests | Should -Be '' -Because \"settings/AllowToAddGuests should be '' but was $($result.AllowToAddGuests)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/AllowToAddGuests should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0028388",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Settings - Classification and M365 Groups - M365 groups - Classification list.",
      "HelpUrl": "https://maester.dev/t/AADSC.settings.ClassificationList",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.ClassificationList | Should -Be '' -Because \"settings/ClassificationList should be '' but was $($result.ClassificationList)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because settings/ClassificationList should be '' but was, but got @($null, $null).",
      "Duration": "00:00:00.0026408",
      "Block": "[-] Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "AADSC: Default Activity Timeout - Enable directory level idle timeout.",
      "HelpUrl": "https://maester.dev/t/AADSC.activityBasedTimeoutPolicies.WebSessionIdleTimeout",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/activityBasedTimeoutPolicies\" -ApiVersion beta\n        $result.definition.ActivityBasedTimeoutPolicy.ApplicationPolicies.WebSessionIdleTimeout | Should -Be '' -Because \"policies/activityBasedTimeoutPolicies/definition.ActivityBasedTimeoutPolicy.ApplicationPolicies.WebSessionIdleTimeout should be '' but was $($result.definition.ActivityBasedTimeoutPolicy.ApplicationPolicies.WebSessionIdleTimeout)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/activityBasedTimeoutPolicies/definition.ActivityBasedTimeoutPolicy.ApplicationPolicies.WebSessionIdleTimeout should be '' but was, but got $null.",
      "Duration": "00:00:00.0443855",
      "Block": "[-] Default Activity Timeout"
    },
    {
      "Name": "AADSC: External Identities - External user leave settings.",
      "HelpUrl": "https://maester.dev/t/AADSC.externalIdentitiesPolicy.allowExternalIdentitiesToLeave",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/externalIdentitiesPolicy\" -ApiVersion beta\n        $result.allowExternalIdentitiesToLeave | Should -Be '' -Because \"policies/externalIdentitiesPolicy/allowExternalIdentitiesToLeave should be '' but was $($result.allowExternalIdentitiesToLeave)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/externalIdentitiesPolicy/allowExternalIdentitiesToLeave should be '' but was True, but got $true.",
      "Duration": "00:00:00.0552439",
      "Block": "[-] External Identities"
    },
    {
      "Name": "AADSC: External Identities - Deleted Identities Data Removal.",
      "HelpUrl": "https://maester.dev/t/AADSC.externalIdentitiesPolicy.allowDeletedIdentitiesDataRemoval",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/externalIdentitiesPolicy\" -ApiVersion beta\n        $result.allowDeletedIdentitiesDataRemoval | Should -Be '' -Because \"policies/externalIdentitiesPolicy/allowDeletedIdentitiesDataRemoval should be '' but was $($result.allowDeletedIdentitiesDataRemoval)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/externalIdentitiesPolicy/allowDeletedIdentitiesDataRemoval should be '' but was False, but got $false.",
      "Duration": "00:00:00.0030642",
      "Block": "[-] External Identities"
    },
    {
      "Name": "AADSC: Feature Rollout (Enabled Previews) - .",
      "HelpUrl": "https://maester.dev/t/AADSC.featureRolloutPolicies.featureRolloutPolicy",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/featureRolloutPolicies\" -ApiVersion beta\n        $result.value | Should -Be '' -Because \"policies/featureRolloutPolicies/value should be '' but was $($result.value)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/featureRolloutPolicies/value should be '' but was, but got $null.",
      "Duration": "00:00:01.2041624",
      "Block": "[-] Feature Rollout (Enabled Previews)"
    },
    {
      "Name": "AADSC: Authentication Method - General Settings - Manage migration.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.policyMigrationState",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.policyMigrationState | Should -Be 'migrationComplete' -Because \"policies/authenticationMethodsPolicy/policyMigrationState should be 'migrationComplete' but was $($result.policyMigrationState)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/policyMigrationState should be 'migrationComplete' but was migrationInProgress, but they were different.\nExpected length: 17\nActual length:   19\nStrings differ at index 9.\nExpected: 'migrationComplete'\nBut was:  'migrationInProgress'\n           ---------^",
      "Duration": "00:00:01.8557965",
      "Block": "[-] Authentication Method - General Settings"
    },
    {
      "Name": "AADSC: Authentication Method - General Settings - Report suspicious activity - State.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.reportSuspiciousActivitySettingsState",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.reportSuspiciousActivitySettings.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.state should be 'enabled' but was $($result.reportSuspiciousActivitySettings.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.state should be 'enabled' but was default, but they were different.\nString lengths are both 7.\nStrings differ at index 0.\nExpected: 'enabled'\nBut was:  'default'\n           ^",
      "Duration": "00:00:00.0143045",
      "Block": "[-] Authentication Method - General Settings"
    },
    {
      "Name": "AADSC: Authentication Method - General Settings - Report suspicious activity - Included users/groups.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.reportSuspiciousActivitySettingsIncluded",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.reportSuspiciousActivitySettings.includeTargets.id | Should -Be 'all_users' -Because \"policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.includeTargets.id should be 'all_users' but was $($result.reportSuspiciousActivitySettings.includeTargets.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'all_users', because policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.includeTargets.id should be 'all_users' but was, but got $null.",
      "Duration": "00:00:00.0047494",
      "Block": "[-] Authentication Method - General Settings"
    },
    {
      "Name": "AADSC: Authentication Method - General Settings - Report suspicious activity - Reporting code.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.reportSuspiciousActivitySettingsReporting code",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.reportSuspiciousActivitySettings.voiceReportingCode | Should -Be '' -Because \"policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.voiceReportingCode should be '' but was $($result.reportSuspiciousActivitySettings.voiceReportingCode)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.voiceReportingCode should be '' but was 0, but got 0.",
      "Duration": "00:00:00.0044287",
      "Block": "[-] Authentication Method - General Settings"
    },
    {
      "Name": "AADSC: Authentication Method - General Settings - System Credential Preferences - State.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.systemCredentialPreferencesState",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.systemCredentialPreferences.state | Should -Be '' -Because \"policies/authenticationMethodsPolicy/systemCredentialPreferences.state should be '' but was $($result.systemCredentialPreferences.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/systemCredentialPreferences.state should be '' but was enabled, but they were different.\nExpected length: 0\nActual length:   7\nStrings differ at index 0.\nExpected: ''\nBut was:  'enabled'\n           ^",
      "Duration": "00:00:00.0082036",
      "Block": "[-] Authentication Method - General Settings"
    },
    {
      "Name": "AADSC: Authentication Method - General Settings - System Credential Preferences - Included users/groups.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.systemCredentialPreferencesStateIncluded",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.systemCredentialPreferences.includeTargets.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/systemCredentialPreferences.includeTargets.id should be '' but was $($result.systemCredentialPreferences.includeTargets.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/systemCredentialPreferences.includeTargets.id should be '' but was all_users, but they were different.\nExpected length: 0\nActual length:   9\nStrings differ at index 0.\nExpected: ''\nBut was:  'all_users'\n           ^",
      "Duration": "00:00:00.0038436",
      "Block": "[-] Authentication Method - General Settings"
    },
    {
      "Name": "AADSC: Authentication Method - General Settings - System Credential Preferences - Excluded users/groups.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.systemCredentialPreferencesStateExcluded",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.systemCredentialPreferences.excludeTargets.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/systemCredentialPreferences.excludeTargets.id should be '' but was $($result.systemCredentialPreferences.excludeTargets.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/systemCredentialPreferences.excludeTargets.id should be '' but was, but got $null.",
      "Duration": "00:00:00.0034145",
      "Block": "[-] Authentication Method - General Settings"
    },
    {
      "Name": "AADSC: Authentication Method - General Settings - Registration campaign - State.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignState",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.state | Should -Be '' -Because \"policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.state should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.state should be '' but was default, but they were different.\nExpected length: 0\nActual length:   7\nStrings differ at index 0.\nExpected: ''\nBut was:  'default'\n           ^",
      "Duration": "00:00:00.0034071",
      "Block": "[-] Authentication Method - General Settings"
    },
    {
      "Name": "AADSC: Authentication Method - General Settings - Registration campaign - Included users/groups.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignIncluded",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.id should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.id should be '' but was all_users, but they were different.\nExpected length: 0\nActual length:   9\nStrings differ at index 0.\nExpected: ''\nBut was:  'all_users'\n           ^",
      "Duration": "00:00:00.0085328",
      "Block": "[-] Authentication Method - General Settings"
    },
    {
      "Name": "AADSC: Authentication Method - General Settings - Registration campaign - Authentication Method.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignTargetedAuthenticationMethod",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.targetedAuthenticationMethod | Should -Be '' -Because \"policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.targetedAuthenticationMethod should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.targetedAuthenticationMethod)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.targetedAuthenticationMethod should be '' but was microsoftAuthenticator, but they were different.\nExpected length: 0\nActual length:   22\nStrings differ at index 0.\nExpected: ''\nBut was:  'microsoftAuthenticator'\n           ^",
      "Duration": "00:00:00.0032846",
      "Block": "[-] Authentication Method - General Settings"
    },
    {
      "Name": "AADSC: Authentication Method - General Settings - Registration campaign - Excluded users/groups.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignExcluded",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.excludeTargets.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.excludeTargets.id should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.excludeTargets.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.excludeTargets.id should be '' but was, but got $null.",
      "Duration": "00:00:00.0028747",
      "Block": "[-] Authentication Method - General Settings"
    },
    {
      "Name": "AADSC: Authentication Method - General Settings - Registration campaign - Days allowed to snooze.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignSnoozeDurationInDays",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.snoozeDurationInDays | Should -Be '' -Because \"policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.snoozeDurationInDays should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.snoozeDurationInDays)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.snoozeDurationInDays should be '' but was 7, but got 7.",
      "Duration": "00:00:00.0063864",
      "Block": "[-] Authentication Method - General Settings"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - State.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.state",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/state should be 'enabled' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:01.4262572",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - Allow use of Microsoft Authenticator OTP.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.isSoftwareOathEnabled",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/state should be 'enabled' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0061417",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - Require number matching for push notifications.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.numberMatchingRequiredState",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.numberMatchingRequiredState.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.state should be 'enabled' but was $($result.featureSettings.numberMatchingRequiredState.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0035406",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.numberMatchingRequiredStateIncluded",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.numberMatchingRequiredState.includeTarget.id | Should -Be 'all_users' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.includeTarget.id should be 'all_users' but was $($result.featureSettings.numberMatchingRequiredState.includeTarget.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0088700",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - Excluded users/groups of number matching for push notifications.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.numberMatchingRequiredStateExcluded",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.numberMatchingRequiredState.excludeTarget.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.excludeTarget.id should be '' but was $($result.featureSettings.numberMatchingRequiredState.excludeTarget.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.excludeTarget.id should be '' but was 00000000-0000-0000-0000-000000000000, but they were different.\nExpected length: 0\nActual length:   36\nStrings differ at index 0.\nExpected: ''\nBut was:  '00000000-0000-0000-0000-000000000000'\n           ^",
      "Duration": "00:00:00.0060698",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.displayAppInformationRequiredState",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayAppInformationRequiredState.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.state should be 'enabled' but was $($result.featureSettings.displayAppInformationRequiredState.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0037075",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.displayAppInformationRequiredStateIncluded",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayAppInformationRequiredState.includeTarget.id | Should -Be 'all_users' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.includeTarget.id should be 'all_users' but was $($result.featureSettings.displayAppInformationRequiredState.includeTarget.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0021307",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - Excluded users/groups to show application name in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.displayAppInformationRequiredStateExcluded",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayAppInformationRequiredState.excludeTarget.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.excludeTarget.id should be '' but was $($result.featureSettings.displayAppInformationRequiredState.excludeTarget.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.excludeTarget.id should be '' but was 00000000-0000-0000-0000-000000000000, but they were different.\nExpected length: 0\nActual length:   36\nStrings differ at index 0.\nExpected: ''\nBut was:  '00000000-0000-0000-0000-000000000000'\n           ^",
      "Duration": "00:00:00.0100413",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.displayLocationInformationRequiredState",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayLocationInformationRequiredState.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.state should be 'enabled' but was $($result.featureSettings.displayLocationInformationRequiredState.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0022564",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.displayLocationInformationRequiredStateIncluded",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayLocationInformationRequiredState.includeTarget.id | Should -Be 'all_users' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.includeTarget.id should be 'all_users' but was $($result.featureSettings.displayLocationInformationRequiredState.includeTarget.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0017571",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - Excluded users/groups to show geographic location in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.displayLocationInformationRequiredExcluded",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayLocationInformationRequiredState.excludeTarget.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.excludeTarget.id should be '' but was $($result.featureSettings.displayLocationInformationRequiredState.excludeTarget.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.excludeTarget.id should be '' but was 00000000-0000-0000-0000-000000000000, but they were different.\nExpected length: 0\nActual length:   36\nStrings differ at index 0.\nExpected: ''\nBut was:  '00000000-0000-0000-0000-000000000000'\n           ^",
      "Duration": "00:00:00.0038137",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - Included users/groups from using Authenticator App.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.includeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False; authenticationMode=deviceBasedPush}, but got @{targetType=group; id=all_users; isRegistrationRequired=False; authenticationMode=deviceBasedPush}.",
      "Duration": "00:00:00.0036452",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - Microsoft Authenticator - Excluded users/groups from using Authenticator App.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.excludeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/excludeTargets should be '' but was, but got $null.",
      "Duration": "00:00:00.0080104",
      "Block": "[-] Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "AADSC: Authentication Method - FIDO2 security key - State.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.state",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/state should be 'enabled' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.7845222",
      "Block": "[-] Authentication Method - FIDO2 security key"
    },
    {
      "Name": "AADSC: Authentication Method - FIDO2 security key - Allow self-service set up.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.isSelfServiceRegistrationAllowed",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.isSelfServiceRegistrationAllowed | Should -Be 'true' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/isSelfServiceRegistrationAllowed should be 'true' but was $($result.isSelfServiceRegistrationAllowed)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0042695",
      "Block": "[-] Authentication Method - FIDO2 security key"
    },
    {
      "Name": "AADSC: Authentication Method - FIDO2 security key - Enforce attestation.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.isAttestationEnforced",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.isAttestationEnforced | Should -Be 'true' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/isAttestationEnforced should be 'true' but was $($result.isAttestationEnforced)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0028710",
      "Block": "[-] Authentication Method - FIDO2 security key"
    },
    {
      "Name": "AADSC: Authentication Method - FIDO2 security key - Enforce key restrictions.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.keyRestrictions.isEnforced",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.keyRestrictions.isEnforced | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.isEnforced should be '' but was $($result.keyRestrictions.isEnforced)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.isEnforced should be '' but was False, but got $false.",
      "Duration": "00:00:00.0123190",
      "Block": "[-] Authentication Method - FIDO2 security key"
    },
    {
      "Name": "AADSC: Authentication Method - FIDO2 security key - Restricted.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.keyRestrictions.aaGuids",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.keyRestrictions.aaGuids | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.aaGuids should be '' but was $($result.keyRestrictions.aaGuids)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.aaGuids should be '' but was, but got $null.",
      "Duration": "00:00:00.0045165",
      "Block": "[-] Authentication Method - FIDO2 security key"
    },
    {
      "Name": "AADSC: Authentication Method - FIDO2 security key - Restrict specific keys.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.keyRestrictions.enforcementType",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.keyRestrictions.enforcementType | Should -Be 'block' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.enforcementType should be 'block' but was $($result.keyRestrictions.enforcementType)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0018594",
      "Block": "[-] Authentication Method - FIDO2 security key"
    },
    {
      "Name": "AADSC: Authentication Method - FIDO2 security key - Included users/groups from using security keys.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.includeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False; allowedPasskeyProfiles=System.Object[]}, but got @{targetType=group; id=all_users; isRegistrationRequired=False; allowedPasskeyProfiles=System.Object[]}.",
      "Duration": "00:00:00.0081229",
      "Block": "[-] Authentication Method - FIDO2 security key"
    },
    {
      "Name": "AADSC: Authentication Method - FIDO2 security key - Excluded users/groups from using security keys.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.excludeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/excludeTargets should be '' but was, but got $null.",
      "Duration": "00:00:00.0035441",
      "Block": "[-] Authentication Method - FIDO2 security key"
    },
    {
      "Name": "AADSC: Authentication Method - Temporary Access Pass - State.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.state",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/state should be 'enabled' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.7511122",
      "Block": "[-] Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "AADSC: Authentication Method - Temporary Access Pass - One-time.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.isUsableOnce",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.isUsableOnce | Should -Be 'false' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/isUsableOnce should be 'false' but was $($result.isUsableOnce)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:00.0057832",
      "Block": "[-] Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "AADSC: Authentication Method - Temporary Access Pass - Default lifetime.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.defaultLifetimeInMinutes",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.defaultLifetimeInMinutes | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/defaultLifetimeInMinutes should be '' but was $($result.defaultLifetimeInMinutes)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/defaultLifetimeInMinutes should be '' but was 60, but got 60.",
      "Duration": "00:00:00.0135014",
      "Block": "[-] Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "AADSC: Authentication Method - Temporary Access Pass - Length.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.defaultLength",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.defaultLength | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/defaultLength should be '' but was $($result.defaultLength)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/defaultLength should be '' but was 8, but got 8.",
      "Duration": "00:00:00.0048407",
      "Block": "[-] Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "AADSC: Authentication Method - Temporary Access Pass - Minimum lifetime.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.minimumLifetimeInMinutes",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.minimumLifetimeInMinutes | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/minimumLifetimeInMinutes should be '' but was $($result.minimumLifetimeInMinutes)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/minimumLifetimeInMinutes should be '' but was 60, but got 60.",
      "Duration": "00:00:00.0043916",
      "Block": "[-] Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "AADSC: Authentication Method - Temporary Access Pass - Maximum lifetime.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.maximumLifetimeInMinutes",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.maximumLifetimeInMinutes | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/maximumLifetimeInMinutes should be '' but was $($result.maximumLifetimeInMinutes)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/maximumLifetimeInMinutes should be '' but was 480, but got 480.",
      "Duration": "00:00:00.0077893",
      "Block": "[-] Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "AADSC: Authentication Method - Temporary Access Pass - Included users/groups from Temporary Access Pass.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.includeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False}, but got @{targetType=group; id=all_users; isRegistrationRequired=False}.",
      "Duration": "00:00:00.0036538",
      "Block": "[-] Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "AADSC: Authentication Method - Temporary Access Pass - Excluded users/group from Temporary Access Pass.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.excludeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/excludeTargets should be '' but was, but got $null.",
      "Duration": "00:00:00.0033533",
      "Block": "[-] Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "AADSC: Authentication Method - Third-party software OATH tokens - State.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.state",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')\" -ApiVersion beta\n        $result.state | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/state should be '' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/state should be '' but was disabled, but they were different.\nExpected length: 0\nActual length:   8\nStrings differ at index 0.\nExpected: ''\nBut was:  'disabled'\n           ^",
      "Duration": "00:00:00.7750059",
      "Block": "[-] Authentication Method - Third-party software OATH tokens"
    },
    {
      "Name": "AADSC: Authentication Method - Third-party software OATH tokens - Included users/groups from OATH token.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.includeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False}, but got @{targetType=group; id=all_users; isRegistrationRequired=False}.",
      "Duration": "00:00:00.0057332",
      "Block": "[-] Authentication Method - Third-party software OATH tokens"
    },
    {
      "Name": "AADSC: Authentication Method - Third-party software OATH tokens - Excluded users/group from OATH token.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.excludeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/excludeTargets should be '' but was, but got $null.",
      "Duration": "00:00:00.0043202",
      "Block": "[-] Authentication Method - Third-party software OATH tokens"
    },
    {
      "Name": "AADSC: Authentication Method - Email OTP - State.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.state",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')\" -ApiVersion beta\n        $result.state | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/state should be '' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/state should be '' but was disabled, but they were different.\nExpected length: 0\nActual length:   8\nStrings differ at index 0.\nExpected: ''\nBut was:  'disabled'\n           ^",
      "Duration": "00:00:00.7806219",
      "Block": "[-] Authentication Method - Email OTP"
    },
    {
      "Name": "AADSC: Authentication Method - Email OTP - Allow external users to use email OTP.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.allowExternalIdToUseEmailOtp",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')\" -ApiVersion beta\n        $result.allowExternalIdToUseEmailOtp | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/allowExternalIdToUseEmailOtp should be '' but was $($result.allowExternalIdToUseEmailOtp)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/allowExternalIdToUseEmailOtp should be '' but was disabled, but they were different.\nExpected length: 0\nActual length:   8\nStrings differ at index 0.\nExpected: ''\nBut was:  'disabled'\n           ^",
      "Duration": "00:00:00.0072816",
      "Block": "[-] Authentication Method - Email OTP"
    },
    {
      "Name": "AADSC: Authentication Method - Email OTP - Included users/groups from Email OTP.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.includeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/includeTargets should be '' but was, but got $null.",
      "Duration": "00:00:00.0046040",
      "Block": "[-] Authentication Method - Email OTP"
    },
    {
      "Name": "AADSC: Authentication Method - Email OTP - Excluded users/group from Email OTP.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.excludeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/excludeTargets should be '' but was, but got $null.",
      "Duration": "00:00:00.0044971",
      "Block": "[-] Authentication Method - Email OTP"
    },
    {
      "Name": "AADSC: Authentication Method - Voice call - State.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.state",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')\" -ApiVersion beta\n        $result.state | Should -Be 'disabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/state should be 'disabled' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "",
      "Duration": "00:00:01.4401976",
      "Block": "[-] Authentication Method - Voice call"
    },
    {
      "Name": "AADSC: Authentication Method - Voice call - Phone Options - Office.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.isOfficePhoneAllowed",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')\" -ApiVersion beta\n        $result.isOfficePhoneAllowed | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/isOfficePhoneAllowed should be '' but was $($result.isOfficePhoneAllowed)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/isOfficePhoneAllowed should be '' but was False, but got $false.",
      "Duration": "00:00:00.0078909",
      "Block": "[-] Authentication Method - Voice call"
    },
    {
      "Name": "AADSC: Authentication Method - Voice call - Included users/groups from Voice call.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.includeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False}, but got @{targetType=group; id=all_users; isRegistrationRequired=False}.",
      "Duration": "00:00:00.0055200",
      "Block": "[-] Authentication Method - Voice call"
    },
    {
      "Name": "AADSC: Authentication Method - Voice call - Excluded users/group from Voice call.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.excludeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/excludeTargets should be '' but was, but got $null.",
      "Duration": "00:00:00.0100609",
      "Block": "[-] Authentication Method - Voice call"
    },
    {
      "Name": "AADSC: Authentication Method - SMS - State.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.state",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')\" -ApiVersion beta\n        $result.state | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/state should be '' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/state should be '' but was enabled, but they were different.\nExpected length: 0\nActual length:   7\nStrings differ at index 0.\nExpected: ''\nBut was:  'enabled'\n           ^",
      "Duration": "00:00:01.7845839",
      "Block": "[-] Authentication Method - SMS"
    },
    {
      "Name": "AADSC: Authentication Method - SMS - Included users/groups from Voice call.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.includeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False; isUsableForSignIn=False}, but got @{targetType=group; id=all_users; isRegistrationRequired=False; isUsableForSignIn=False}.",
      "Duration": "00:00:00.0078561",
      "Block": "[-] Authentication Method - SMS"
    },
    {
      "Name": "AADSC: Authentication Method - SMS - Excluded users/group from Voice call.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.excludeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/excludeTargets should be '' but was, but got $null.",
      "Duration": "00:00:00.0117560",
      "Block": "[-] Authentication Method - SMS"
    },
    {
      "Name": "AADSC: Authentication Method - Certificate-based authentication - State.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.state",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')\" -ApiVersion beta\n        $result.state | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/state should be '' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/state should be '' but was disabled, but they were different.\nExpected length: 0\nActual length:   8\nStrings differ at index 0.\nExpected: ''\nBut was:  'disabled'\n           ^",
      "Duration": "00:00:00.7594019",
      "Block": "[-] Authentication Method - Certificate-based authentication"
    },
    {
      "Name": "AADSC: Authentication Method - Certificate-based authentication - Included users/groups from CBA.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.includeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False}, but got @{targetType=group; id=all_users; isRegistrationRequired=False}.",
      "Duration": "00:00:00.0078102",
      "Block": "[-] Authentication Method - Certificate-based authentication"
    },
    {
      "Name": "AADSC: Authentication Method - Certificate-based authentication - Excluded users/group from CBA.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.excludeTargets",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/excludeTargets should be '' but was, but got $null.",
      "Duration": "00:00:00.0112874",
      "Block": "[-] Authentication Method - Certificate-based authentication"
    },
    {
      "Name": "AADSC: Authentication Method - Certificate-based authentication - Authentication binding - Protected Level.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')\" -ApiVersion beta\n        $result.authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode should be '' but was $($result.authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode should be '' but was x509CertificateSingleFactor, but they were different.\nExpected length: 0\nActual length:   27\nStrings differ at index 0.\nExpected: ''\nBut was:  'x509CertificateSingleFactor'\n           ^",
      "Duration": "00:00:00.0048872",
      "Block": "[-] Authentication Method - Certificate-based authentication"
    },
    {
      "Name": "AADSC: Authentication Method - Certificate-based authentication - Authentication binding - Rules.",
      "HelpUrl": "https://maester.dev/t/AADSC.authenticationMethodsPolicy.authenticationModeConfiguration.rules",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')\" -ApiVersion beta\n        $result.authenticationModeConfiguration.rules | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/authenticationModeConfiguration.rules should be '' but was $($result.authenticationModeConfiguration.rules)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/authenticationModeConfiguration.rules should be '' but was, but got $null.",
      "Duration": "00:00:00.0062796",
      "Block": "[-] Authentication Method - Certificate-based authentication"
    },
    {
      "Name": "AADSC: Consent Framework - Admin Consent Request (Coming soon) - Users can request admin consent to apps they are unable to consent to.",
      "HelpUrl": "https://maester.dev/t/AADSC.servicePrincipalCreationPolicies.isEnabled",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.isEnabled | Should -Be 'true' -Because \"policies/adminConsentRequestPolicy/isEnabled should be 'true' but was $($result.isEnabled)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'true', because policies/adminConsentRequestPolicy/isEnabled should be 'true' but was False, but got $false.",
      "Duration": "00:00:04.3994865",
      "Block": "[-] Consent Framework - Admin Consent Request (Coming soon)"
    },
    {
      "Name": "AADSC: Consent Framework - Admin Consent Request (Coming soon) - Reviewers will receive email notifications for requests???.",
      "HelpUrl": "https://maester.dev/t/AADSC.servicePrincipalCreationPolicies.notifyReviewers",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.notifyReviewers | Should -Be 'true' -Because \"policies/adminConsentRequestPolicy/notifyReviewers should be 'true' but was $($result.notifyReviewers)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'true', because policies/adminConsentRequestPolicy/notifyReviewers should be 'true' but was False, but got $false.",
      "Duration": "00:00:00.0080380",
      "Block": "[-] Consent Framework - Admin Consent Request (Coming soon)"
    },
    {
      "Name": "AADSC: Consent Framework - Admin Consent Request (Coming soon) - Reviewers will receive email notifications when admin consent requests are about to expire???.",
      "HelpUrl": "https://maester.dev/t/AADSC.servicePrincipalCreationPolicies.notifyReviewers",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.notifyReviewers | Should -Be 'true' -Because \"policies/adminConsentRequestPolicy/notifyReviewers should be 'true' but was $($result.notifyReviewers)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected 'true', because policies/adminConsentRequestPolicy/notifyReviewers should be 'true' but was False, but got $false.",
      "Duration": "00:00:00.0053856",
      "Block": "[-] Consent Framework - Admin Consent Request (Coming soon)"
    },
    {
      "Name": "AADSC: Consent Framework - Admin Consent Request (Coming soon) - Consent request expires after (days)???.",
      "HelpUrl": "https://maester.dev/t/AADSC.servicePrincipalCreationPolicies.requestDurationInDays",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.requestDurationInDays | Should -Be '30' -Because \"policies/adminConsentRequestPolicy/requestDurationInDays should be '30' but was $($result.requestDurationInDays)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected '30', because policies/adminConsentRequestPolicy/requestDurationInDays should be '30' but was 0, but got 0.",
      "Duration": "00:00:00.0105456",
      "Block": "[-] Consent Framework - Admin Consent Request (Coming soon)"
    },
    {
      "Name": "AADSC: Consent Framework - Admin Consent Request (Coming soon) - Consent request expires after (days)???.",
      "HelpUrl": "https://maester.dev/t/AADSC.servicePrincipalCreationPolicies.reviewers",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.reviewers | Should -Be '30' -Because \"policies/adminConsentRequestPolicy/reviewers should be '30' but was $($result.reviewers)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected '30', because policies/adminConsentRequestPolicy/reviewers should be '30' but was, but got $null.",
      "Duration": "00:00:00.0040545",
      "Block": "[-] Consent Framework - Admin Consent Request (Coming soon)"
    },
    {
      "Name": "AADSC: Consent Framework - Admin Consent Request (Coming soon) - Consent request expires after (days)???.",
      "HelpUrl": "https://maester.dev/t/AADSC.servicePrincipalCreationPolicies.version",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.version | Should -Be '' -Because \"policies/adminConsentRequestPolicy/version should be '' but was $($result.version)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "Expected <empty>, because policies/adminConsentRequestPolicy/version should be '' but was 0, but got 0.",
      "Duration": "00:00:00.0039028",
      "Block": "[-] Consent Framework - Admin Consent Request (Coming soon)"
    },
    {
      "Name": "AADSC: Azure AD Recommendations - Protect all users with a user risk policy.",
      "HelpUrl": "https://maester.dev/t/AADSC.recommendations.Microsoft.Identity.IAM.Insights.UserRiskPolicy",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"directory/recommendations\" -ApiVersion beta\n        $result.status | Should -Be 'completedBySystem' -Because \"directory/recommendations/status should be 'completedBySystem' but was $($result.status)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "GET https://graph.microsoft.com/beta/directory/recommendations\r\nHTTP/1.1 403 Forbidden\r\nTransfer-Encoding: chunked\r\nVary: Accept-Encoding\r\nStrict-Transport-Security: max-age=31536000\r\nrequest-id: 2bde51c6-949e-4d0a-93a9-0b6bbe2602f0\r\nclient-request-id: 7244a457-83ac-43a6-badc-e97d1a34548d\r\nx-ms-ags-diagnostic: {\"ServerInfo\":{\"DataCenter\":\"Australia Southeast\",\"Slice\":\"E\",\"Ring\":\"4\",\"ScaleUnit\":\"002\",\"RoleInstance\":\"ML1PEPF00005BF8\"}}\r\nDate: Sat, 20 Jan 2024 06:01:20 GMT\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\n\r\n{\"error\":{\"code\":\"Authentication_MSGraphPermissionMissing\",\"message\":\"Calling principal does not have required MSGraph permissions DirectoryRecommendations.Read.All,DirectoryRecommendations.ReadWrite.All\",\"innerError\":{\"date\":\"2024-01-20T06:01:20\",\"request-id\":\"2bde51c6-949e-4d0a-93a9-0b6bbe2602f0\",\"client-request-id\":\"7244a457-83ac-43a6-badc-e97d1a34548d\"}}}",
      "Duration": "00:00:00.0707067",
      "Block": "[-] Azure AD Recommendations"
    },
    {
      "Name": "AADSC: Azure AD Recommendations - Protect all users with a sign-in risk policy.",
      "HelpUrl": "https://maester.dev/t/AADSC.recommendations.Microsoft.Identity.IAM.Insights.SigninRiskPolicy",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"directory/recommendations\" -ApiVersion beta\n        $result.status | Should -Be 'completedBySystem' -Because \"directory/recommendations/status should be 'completedBySystem' but was $($result.status)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "GET https://graph.microsoft.com/beta/directory/recommendations\r\nHTTP/1.1 403 Forbidden\r\nTransfer-Encoding: chunked\r\nVary: Accept-Encoding\r\nStrict-Transport-Security: max-age=31536000\r\nrequest-id: 6f6e45cb-8785-4563-9503-d553039e2767\r\nclient-request-id: 08a5c5c2-bf91-466b-b1a3-0c65fd69e8a9\r\nx-ms-ags-diagnostic: {\"ServerInfo\":{\"DataCenter\":\"Australia Southeast\",\"Slice\":\"E\",\"Ring\":\"4\",\"ScaleUnit\":\"002\",\"RoleInstance\":\"ML1PEPF00005BF8\"}}\r\nDate: Sat, 20 Jan 2024 06:01:20 GMT\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\n\r\n{\"error\":{\"code\":\"Authentication_MSGraphPermissionMissing\",\"message\":\"Calling principal does not have required MSGraph permissions DirectoryRecommendations.Read.All,DirectoryRecommendations.ReadWrite.All\",\"innerError\":{\"date\":\"2024-01-20T06:01:20\",\"request-id\":\"6f6e45cb-8785-4563-9503-d553039e2767\",\"client-request-id\":\"08a5c5c2-bf91-466b-b1a3-0c65fd69e8a9\"}}}",
      "Duration": "00:00:00.0621503",
      "Block": "[-] Azure AD Recommendations"
    },
    {
      "Name": "AADSC: Azure AD Recommendations - Require multifactor authentication for administrative roles.",
      "HelpUrl": "https://maester.dev/t/AADSC.recommendations.Microsoft.Identity.IAM.Insights.AdminMFAV2",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"directory/recommendations\" -ApiVersion beta\n        $result.status | Should -Be 'completedBySystem' -Because \"directory/recommendations/status should be 'completedBySystem' but was $($result.status)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "GET https://graph.microsoft.com/beta/directory/recommendations\r\nHTTP/1.1 403 Forbidden\r\nTransfer-Encoding: chunked\r\nVary: Accept-Encoding\r\nStrict-Transport-Security: max-age=31536000\r\nrequest-id: 25be98f7-4328-40d6-8578-af9b54c622d6\r\nclient-request-id: 4d929c04-df7b-49bf-97a2-e28ecb95a344\r\nx-ms-ags-diagnostic: {\"ServerInfo\":{\"DataCenter\":\"Australia Southeast\",\"Slice\":\"E\",\"Ring\":\"4\",\"ScaleUnit\":\"002\",\"RoleInstance\":\"ML1PEPF00005BF8\"}}\r\nDate: Sat, 20 Jan 2024 06:01:20 GMT\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\n\r\n{\"error\":{\"code\":\"Authentication_MSGraphPermissionMissing\",\"message\":\"Calling principal does not have required MSGraph permissions DirectoryRecommendations.Read.All,DirectoryRecommendations.ReadWrite.All\",\"innerError\":{\"date\":\"2024-01-20T06:01:20\",\"request-id\":\"25be98f7-4328-40d6-8578-af9b54c622d6\",\"client-request-id\":\"4d929c04-df7b-49bf-97a2-e28ecb95a344\"}}}",
      "Duration": "00:00:00.0663693",
      "Block": "[-] Azure AD Recommendations"
    },
    {
      "Name": "AADSC: Azure AD Recommendations - Use limited administrative roles.",
      "HelpUrl": "https://maester.dev/t/AADSC.recommendations.Microsoft.Identity.IAM.Insights.RoleOverlap",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"directory/recommendations\" -ApiVersion beta\n        $result.status | Should -Be 'completedBySystem' -Because \"directory/recommendations/status should be 'completedBySystem' but was $($result.status)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "GET https://graph.microsoft.com/beta/directory/recommendations\r\nHTTP/1.1 403 Forbidden\r\nTransfer-Encoding: chunked\r\nVary: Accept-Encoding\r\nStrict-Transport-Security: max-age=31536000\r\nrequest-id: b43acf92-cfe6-447d-8a64-02f18f83e58a\r\nclient-request-id: 21985012-7cb9-4aa2-b816-96742ff73b86\r\nx-ms-ags-diagnostic: {\"ServerInfo\":{\"DataCenter\":\"Australia Southeast\",\"Slice\":\"E\",\"Ring\":\"4\",\"ScaleUnit\":\"002\",\"RoleInstance\":\"ML1PEPF00005BF8\"}}\r\nDate: Sat, 20 Jan 2024 06:01:20 GMT\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\n\r\n{\"error\":{\"code\":\"Authentication_MSGraphPermissionMissing\",\"message\":\"Calling principal does not have required MSGraph permissions DirectoryRecommendations.Read.All,DirectoryRecommendations.ReadWrite.All\",\"innerError\":{\"date\":\"2024-01-20T06:01:20\",\"request-id\":\"b43acf92-cfe6-447d-8a64-02f18f83e58a\",\"client-request-id\":\"21985012-7cb9-4aa2-b816-96742ff73b86\"}}}",
      "Duration": "00:00:00.0529309",
      "Block": "[-] Azure AD Recommendations"
    },
    {
      "Name": "AADSC: Azure AD Recommendations - Remove unused applications.",
      "HelpUrl": "https://maester.dev/t/AADSC.recommendations.Microsoft.Identity.IAM.Insights.StaleApps",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"directory/recommendations\" -ApiVersion beta\n        $result.status | Should -Be 'completedBySystem' -Because \"directory/recommendations/status should be 'completedBySystem' but was $($result.status)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "GET https://graph.microsoft.com/beta/directory/recommendations\r\nHTTP/1.1 403 Forbidden\r\nTransfer-Encoding: chunked\r\nVary: Accept-Encoding\r\nStrict-Transport-Security: max-age=31536000\r\nrequest-id: 35d49fb5-3df2-43a1-90d2-10de5a529d67\r\nclient-request-id: e761637e-a108-4973-90e7-e90ff44e54df\r\nx-ms-ags-diagnostic: {\"ServerInfo\":{\"DataCenter\":\"Australia Southeast\",\"Slice\":\"E\",\"Ring\":\"4\",\"ScaleUnit\":\"002\",\"RoleInstance\":\"ML1PEPF00005BF8\"}}\r\nDate: Sat, 20 Jan 2024 06:01:20 GMT\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\n\r\n{\"error\":{\"code\":\"Authentication_MSGraphPermissionMissing\",\"message\":\"Calling principal does not have required MSGraph permissions DirectoryRecommendations.Read.All,DirectoryRecommendations.ReadWrite.All\",\"innerError\":{\"date\":\"2024-01-20T06:01:21\",\"request-id\":\"35d49fb5-3df2-43a1-90d2-10de5a529d67\",\"client-request-id\":\"e761637e-a108-4973-90e7-e90ff44e54df\"}}}",
      "Duration": "00:00:00.7214334",
      "Block": "[-] Azure AD Recommendations"
    },
    {
      "Name": "AADSC: Azure AD Recommendations - Renew expiring application credentials.",
      "HelpUrl": "https://maester.dev/t/AADSC.recommendations.Microsoft.Identity.IAM.Insights.ApplicationCredentialExpiry",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"directory/recommendations\" -ApiVersion beta\n        $result.status | Should -Be 'completedBySystem' -Because \"directory/recommendations/status should be 'completedBySystem' but was $($result.status)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/AADSCAv3/Test-AADSCA.Generated.Tests.ps1",
      "ErrorRecord": "GET https://graph.microsoft.com/beta/directory/recommendations\r\nHTTP/1.1 403 Forbidden\r\nTransfer-Encoding: chunked\r\nVary: Accept-Encoding\r\nStrict-Transport-Security: max-age=31536000\r\nrequest-id: a58bf0f0-f305-4dbb-9b06-41895aed028e\r\nclient-request-id: 2073ab68-a443-4b88-80d0-993e401b3508\r\nx-ms-ags-diagnostic: {\"ServerInfo\":{\"DataCenter\":\"Australia Southeast\",\"Slice\":\"E\",\"Ring\":\"4\",\"ScaleUnit\":\"002\",\"RoleInstance\":\"ML1PEPF00005BF8\"}}\r\nDate: Sat, 20 Jan 2024 06:01:21 GMT\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\n\r\n{\"error\":{\"code\":\"Authentication_MSGraphPermissionMissing\",\"message\":\"Calling principal does not have required MSGraph permissions DirectoryRecommendations.Read.All,DirectoryRecommendations.ReadWrite.All\",\"innerError\":{\"date\":\"2024-01-20T06:01:21\",\"request-id\":\"a58bf0f0-f305-4dbb-9b06-41895aed028e\",\"client-request-id\":\"2073ab68-a443-4b88-80d0-993e401b3508\"}}}",
      "Duration": "00:00:00.9931136",
      "Block": "[-] Azure AD Recommendations"
    }
  ],
  "Blocks": [
    {
      "Name": "App Management Policies",
      "Result": "Failed",
      "FailedCount": 1,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 1,
      "Duration": "00:00:01.0143614",
      "Tag": "App Security All"
    },
    {
      "Name": "Conditional Access Baseline Policies",
      "Result": "Failed",
      "FailedCount": 3,
      "PassedCount": 3,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 6,
      "Duration": "00:00:03.8724456",
      "Tag": "CA Security All"
    },
    {
      "Name": "Default Authorization Settings",
      "Result": "Failed",
      "FailedCount": 11,
      "PassedCount": 3,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 14,
      "Duration": "00:00:00.1314707",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Default Settings - Consent Policy Settings",
      "Result": "Failed",
      "FailedCount": 4,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 4,
      "Duration": "00:00:00.1823422",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Default Settings - Password Rule Settings",
      "Result": "Failed",
      "FailedCount": 6,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 6,
      "Duration": "00:00:00.2094646",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Default Settings - Classification and M365 Groups",
      "Result": "Failed",
      "FailedCount": 14,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 14,
      "Duration": "00:00:00.2608057",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Default Activity Timeout",
      "Result": "Failed",
      "FailedCount": 1,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 1,
      "Duration": "00:00:00.3067744",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "External Identities",
      "Result": "Failed",
      "FailedCount": 2,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 2,
      "Duration": "00:00:00.3687649",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Feature Rollout (Enabled Previews)",
      "Result": "Failed",
      "FailedCount": 1,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 1,
      "Duration": "00:00:01.5744598",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Authentication Method - General Settings",
      "Result": "Failed",
      "FailedCount": 12,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 12,
      "Duration": "00:00:03.4952845",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Authentication Method - Microsoft Authenticator",
      "Result": "Failed",
      "FailedCount": 5,
      "PassedCount": 8,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 13,
      "Duration": "00:00:04.9829014",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Authentication Method - FIDO2 security key",
      "Result": "Failed",
      "FailedCount": 4,
      "PassedCount": 4,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 8,
      "Duration": "00:00:05.8061645",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Authentication Method - Temporary Access Pass",
      "Result": "Failed",
      "FailedCount": 6,
      "PassedCount": 2,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 8,
      "Duration": "00:00:06.6018187",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Authentication Method - Third-party software OATH tokens",
      "Result": "Failed",
      "FailedCount": 3,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 3,
      "Duration": "00:00:07.3880878",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Authentication Method - Email OTP",
      "Result": "Failed",
      "FailedCount": 4,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 4,
      "Duration": "00:00:08.1902469",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Authentication Method - Voice call",
      "Result": "Failed",
      "FailedCount": 3,
      "PassedCount": 1,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 4,
      "Duration": "00:00:09.6553150",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Authentication Method - SMS",
      "Result": "Failed",
      "FailedCount": 3,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 3,
      "Duration": "00:00:11.4610359",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Authentication Method - Certificate-based authentication",
      "Result": "Failed",
      "FailedCount": 5,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 5,
      "Duration": "00:00:12.2523954",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Consent Framework - Admin Consent Request (Coming soon)",
      "Result": "Failed",
      "FailedCount": 6,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 6,
      "Duration": "00:00:16.6862941",
      "Tag": "AADSCA Security All"
    },
    {
      "Name": "Azure AD Recommendations",
      "Result": "Failed",
      "FailedCount": 6,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 6,
      "Duration": "00:00:18.6547363",
      "Tag": "AADSCA Security All"
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
        <Grid numItemsSm={1} numItemsLg={2} className="gap-6 mb-12 h-50">
          <MtDonutChart
            TotalCount={testResults.TotalCount}
            PassedCount={testResults.PassedCount}
            FailedCount={testResults.FailedCount}
            SkippedCount={testResults.SkippedCount}
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
