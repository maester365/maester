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
  "FailedCount": 96,
  "PassedCount": 18,
  "SkippedCount": 0,
  "TotalCount": 142,
  "ExecutedAt": "2024-03-22T21:40:25.079856+11:00",
  "TenantId": "0817c655-a853-4d8f-9723-3a333b5b9235",
  "TenantName": "",
  "Account": "merill@elapora.com",
  "Tests": [
    {
      "Name": "EIDSCA: Default Authorization Settings - Enabled Self service password reset.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToUseSSPR",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToUseSSPR | Should -Be 'true' -Because \"policies/authorizationPolicy/allowedToUseSSPR should be 'true' but was $($result.allowedToUseSSPR)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - Blocked MSOnline PowerShell access.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.blockMsolPowerShell",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.blockMsolPowerShell | Should -Be '' -Because \"policies/authorizationPolicy/blockMsolPowerShell should be '' but was $($result.blockMsolPowerShell)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authorizationPolicy/blockMsolPowerShell should be '' but was False, but got $false."
      ],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - Enabled .",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.enabledPreviewFeatures",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.enabledPreviewFeatures | Should -Be '' -Because \"policies/authorizationPolicy/enabledPreviewFeatures should be '' but was $($result.enabledPreviewFeatures)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authorizationPolicy/enabledPreviewFeatures should be '' but was, but got $null."
      ],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - Guest invite restrictions.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.allowInvitesFrom",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowInvitesFrom | Should -Be 'adminsAndGuestInviters' -Because \"policies/authorizationPolicy/allowInvitesFrom should be 'adminsAndGuestInviters' but was $($result.allowInvitesFrom)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authorizationPolicy/allowInvitesFrom should be 'adminsAndGuestInviters' but was everyone, but they were different.\nExpected length: 22\nActual length:   8\nStrings differ at index 0.\nExpected: 'adminsAndGuestInviters'\nBut was:  'everyone'\n           ^"
      ],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - Sign-up for email based subscription.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToSignUpEmailBasedSubscriptions",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToSignUpEmailBasedSubscriptions | Should -Be 'false' -Because \"policies/authorizationPolicy/allowedToSignUpEmailBasedSubscriptions should be 'false' but was $($result.allowedToSignUpEmailBasedSubscriptions)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'false', because policies/authorizationPolicy/allowedToSignUpEmailBasedSubscriptions should be 'false' but was True, but got $true."
      ],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - User can joint the tenant by email validation.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.allowEmailVerifiedUsersToJoinOrganization",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowEmailVerifiedUsersToJoinOrganization | Should -Be 'false' -Because \"policies/authorizationPolicy/allowEmailVerifiedUsersToJoinOrganization should be 'false' but was $($result.allowEmailVerifiedUsersToJoinOrganization)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'false', because policies/authorizationPolicy/allowEmailVerifiedUsersToJoinOrganization should be 'false' but was True, but got $true."
      ],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - Guest user access.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.guestUserRoleId",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.guestUserRoleId | Should -Be '2af84b1e-32c8-42b7-82bc-daa82404023b' -Because \"policies/authorizationPolicy/guestUserRoleId should be '2af84b1e-32c8-42b7-82bc-daa82404023b' but was $($result.guestUserRoleId)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authorizationPolicy/guestUserRoleId should be '2af84b1e-32c8-42b7-82bc-daa82404023b' but was 10dae51f-b6af-4016-8d66-8c2a99b929b3, but they were different.\nString lengths are both 36.\nStrings differ at index 0.\nExpected: '2af84b1e-32c8-42b7-82bc-daa82404023b'\nBut was:  '10dae51f-b6af-4016-8d66-8c2a99b929b3'\n           ^"
      ],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - User consent policy assigned for applications.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.permissionGrantPolicyIdsAssignedToDefaultUserRole",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.permissionGrantPolicyIdsAssignedToDefaultUserRole | Should -Be 'ManagePermissionGrantsForSelf.microsoft-user-default-low' -Because \"policies/authorizationPolicy/permissionGrantPolicyIdsAssignedToDefaultUserRole should be 'ManagePermissionGrantsForSelf.microsoft-user-default-low' but was $($result.permissionGrantPolicyIdsAssignedToDefaultUserRole)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'ManagePermissionGrantsForSelf.microsoft-user-default-low', because policies/authorizationPolicy/permissionGrantPolicyIdsAssignedToDefaultUserRole should be 'ManagePermissionGrantsForSelf.microsoft-user-default-low' but was ManagePermissionGrantsForSelf.microsoft-user-default-legacy ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-team ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-chat, but got @('ManagePermissionGrantsForSelf.microsoft-user-default-legacy', 'ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-team', 'ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-chat')."
      ],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - Risk-based step-up consent.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.allowUserConsentForRiskyApps",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowUserConsentForRiskyApps | Should -Be 'false' -Because \"policies/authorizationPolicy/allowUserConsentForRiskyApps should be 'false' but was $($result.allowUserConsentForRiskyApps)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - Default User Role Permissions - Allowed to create Apps.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToCreateApps",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.defaultUserRolePermissions.allowedToCreateApps | Should -Be 'false' -Because \"policies/authorizationPolicy/defaultUserRolePermissions.allowedToCreateApps should be 'false' but was $($result.defaultUserRolePermissions.allowedToCreateApps)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - Default User Role Permissions - Allowed to create Security Groups.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToCreateSecurityGroups",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToCreateSecurityGroups | Should -Be '' -Because \"policies/authorizationPolicy/allowedToCreateSecurityGroups should be '' but was $($result.allowedToCreateSecurityGroups)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'allowedToCreateSecurityGroups' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - Default User Role Permissions - Allowed to create Tenants.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToCreateTenants",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToCreateTenants | Should -Be '' -Because \"policies/authorizationPolicy/allowedToCreateTenants should be '' but was $($result.allowedToCreateTenants)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'allowedToCreateTenants' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - Default User Role Permissions - Allowed to read BitLocker Keys for Owned Devices.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToReadBitlockerKeysForOwnedDevice",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToReadBitlockerKeysForOwnedDevice | Should -Be '' -Because \"policies/authorizationPolicy/allowedToReadBitlockerKeysForOwnedDevice should be '' but was $($result.allowedToReadBitlockerKeysForOwnedDevice)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'allowedToReadBitlockerKeysForOwnedDevice' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Authorization Settings - Default User Role Permissions - Allowed to read other users.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToReadOtherUsers",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authorizationPolicy\" -ApiVersion beta\n        $result.allowedToReadOtherUsers | Should -Be 'true' -Because \"policies/authorizationPolicy/allowedToReadOtherUsers should be 'true' but was $($result.allowedToReadOtherUsers)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'allowedToReadOtherUsers' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Authorization Settings"
    },
    {
      "Name": "EIDSCA: Default Settings - Consent Policy Settings - Group owner consent for apps accessing data.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.EnableGroupSpecificConsent",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values.EnableGroupSpecificConsent | Should -Be 'False' -Because \"settings/values.EnableGroupSpecificConsent should be 'False' but was $($result.values.EnableGroupSpecificConsent)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'EnableGroupSpecificConsent' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Consent Policy Settings"
    },
    {
      "Name": "EIDSCA: Default Settings - Consent Policy Settings - Group owner consent for apps accessing data - Restricted to selected group owners.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.ConstrainGroupSpecificConsentToMembersOfGroupId",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values.ConstrainGroupSpecificConsentToMembersOfGroupId | Should -Be '' -Because \"settings/values.ConstrainGroupSpecificConsentToMembersOfGroupId should be '' but was $($result.values.ConstrainGroupSpecificConsentToMembersOfGroupId)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'ConstrainGroupSpecificConsentToMembersOfGroupId' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Consent Policy Settings"
    },
    {
      "Name": "EIDSCA: Default Settings - Consent Policy Settings - Block user consent for risky apps.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.BlockUserConsentForRiskyApps",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values.BlockUserConsentForRiskyApps | Should -Be 'true' -Because \"settings/values.BlockUserConsentForRiskyApps should be 'true' but was $($result.values.BlockUserConsentForRiskyApps)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'BlockUserConsentForRiskyApps' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Consent Policy Settings"
    },
    {
      "Name": "EIDSCA: Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to???.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.EnableAdminConsentRequests",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.values.EnableAdminConsentRequests | Should -Be 'true' -Because \"settings/values.EnableAdminConsentRequests should be 'true' but was $($result.values.EnableAdminConsentRequests)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'EnableAdminConsentRequests' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Consent Policy Settings"
    },
    {
      "Name": "EIDSCA: Default Settings - Password Rule Settings - Password Protection - Mode.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.BannedPasswordCheckOnPremisesMode",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.BannedPasswordCheckOnPremisesMode | Should -Be 'Enforce' -Because \"settings/BannedPasswordCheckOnPremisesMode should be 'Enforce' but was $($result.BannedPasswordCheckOnPremisesMode)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'BannedPasswordCheckOnPremisesMode' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Password Rule Settings"
    },
    {
      "Name": "EIDSCA: Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.EnableBannedPasswordCheckOnPremises",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.EnableBannedPasswordCheckOnPremises | Should -Be 'True' -Because \"settings/EnableBannedPasswordCheckOnPremises should be 'True' but was $($result.EnableBannedPasswordCheckOnPremises)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'EnableBannedPasswordCheckOnPremises' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Password Rule Settings"
    },
    {
      "Name": "EIDSCA: Default Settings - Password Rule Settings - Enforce custom list.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.EnableBannedPasswordCheck",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.EnableBannedPasswordCheck | Should -Be 'True' -Because \"settings/EnableBannedPasswordCheck should be 'True' but was $($result.EnableBannedPasswordCheck)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'EnableBannedPasswordCheck' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Password Rule Settings"
    },
    {
      "Name": "EIDSCA: Default Settings - Password Rule Settings - Password Protection - Custom banned password list.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.BannedPasswordList",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.BannedPasswordList | Should -Be '' -Because \"settings/BannedPasswordList should be '' but was $($result.BannedPasswordList)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'BannedPasswordList' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Password Rule Settings"
    },
    {
      "Name": "EIDSCA: Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.LockoutDurationInSeconds",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.LockoutDurationInSeconds | Should -Be '60' -Because \"settings/LockoutDurationInSeconds should be '60' but was $($result.LockoutDurationInSeconds)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'LockoutDurationInSeconds' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Password Rule Settings"
    },
    {
      "Name": "EIDSCA: Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.LockoutThreshold",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.LockoutThreshold | Should -Be '10' -Because \"settings/LockoutThreshold should be '10' but was $($result.LockoutThreshold)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'LockoutThreshold' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Password Rule Settings"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - Default writeback setting for newly created Microsoft 365 groups.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.NewUnifiedGroupWritebackDefault",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.NewUnifiedGroupWritebackDefault | Should -Be '' -Because \"settings/NewUnifiedGroupWritebackDefault should be '' but was $($result.NewUnifiedGroupWritebackDefault)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'NewUnifiedGroupWritebackDefault' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - Microsoft Information Protection (MIP) Sensitivity labels to Microsoft 365 groups.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.EnableMIPLabels",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.EnableMIPLabels | Should -Be '' -Because \"settings/EnableMIPLabels should be '' but was $($result.EnableMIPLabels)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'EnableMIPLabels' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups naming convention - Custom blocked words list.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.CustomBlockedWordsList",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.CustomBlockedWordsList | Should -Be '' -Because \"settings/CustomBlockedWordsList should be '' but was $($result.CustomBlockedWordsList)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'CustomBlockedWordsList' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups naming convention - Microsoft Standard List of blocked words (deprecated).",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.EnableMSStandardBlockedWords",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.EnableMSStandardBlockedWords | Should -Be '' -Because \"settings/EnableMSStandardBlockedWords should be '' but was $($result.EnableMSStandardBlockedWords)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'EnableMSStandardBlockedWords' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups naming convention - Classification descriptions.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.ClassificationDescriptions",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.ClassificationDescriptions | Should -Be '' -Because \"settings/ClassificationDescriptions should be '' but was $($result.ClassificationDescriptions)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'ClassificationDescriptions' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups naming convention - Default classification.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.DefaultClassification",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.DefaultClassification | Should -Be '' -Because \"settings/DefaultClassification should be '' but was $($result.DefaultClassification)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'DefaultClassification' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups naming convention - prefix/suffix naming requirement.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.PrefixSuffixNamingRequirement",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.PrefixSuffixNamingRequirement | Should -Be '' -Because \"settings/PrefixSuffixNamingRequirement should be '' but was $($result.PrefixSuffixNamingRequirement)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'PrefixSuffixNamingRequirement' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.AllowGuestsToBeGroupOwner",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.AllowGuestsToBeGroupOwner | Should -Be 'false' -Because \"settings/AllowGuestsToBeGroupOwner should be 'false' but was $($result.AllowGuestsToBeGroupOwner)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'AllowGuestsToBeGroupOwner' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.AllowGuestsToAccessGroups",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.AllowGuestsToAccessGroups | Should -Be 'True' -Because \"settings/AllowGuestsToAccessGroups should be 'True' but was $($result.AllowGuestsToAccessGroups)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'AllowGuestsToAccessGroups' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Guest usage guidelines URL.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.GuestUsageGuidelinesUrl",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.GuestUsageGuidelinesUrl | Should -Be '' -Because \"settings/GuestUsageGuidelinesUrl should be '' but was $($result.GuestUsageGuidelinesUrl)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'GuestUsageGuidelinesUrl' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Enable Group creation for any members.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.EnableGroupCreation",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.EnableGroupCreation | Should -Be '' -Because \"settings/EnableGroupCreation should be '' but was $($result.EnableGroupCreation)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'EnableGroupCreation' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Allow group created for a specific security group.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.GroupCreationAllowedGroupId",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.GroupCreationAllowedGroupId | Should -Be '' -Because \"settings/GroupCreationAllowedGroupId should be '' but was $($result.GroupCreationAllowedGroupId)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'GroupCreationAllowedGroupId' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Allow to add Guests.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.AllowToAddGuests",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.AllowToAddGuests | Should -Be '' -Because \"settings/AllowToAddGuests should be '' but was $($result.AllowToAddGuests)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'AllowToAddGuests' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Classification list.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.settings.ClassificationList",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"settings\" -ApiVersion beta\n        $result.ClassificationList | Should -Be '' -Because \"settings/ClassificationList should be '' but was $($result.ClassificationList)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'ClassificationList' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Settings - Classification and M365 Groups"
    },
    {
      "Name": "EIDSCA: Default Activity Timeout - Enable directory level idle timeout.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.activityBasedTimeoutPolicies.WebSessionIdleTimeout",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/activityBasedTimeoutPolicies\" -ApiVersion beta\n        $result.definition.ActivityBasedTimeoutPolicy.ApplicationPolicies.WebSessionIdleTimeout | Should -Be '' -Because \"policies/activityBasedTimeoutPolicies/definition.ActivityBasedTimeoutPolicy.ApplicationPolicies.WebSessionIdleTimeout should be '' but was $($result.definition.ActivityBasedTimeoutPolicy.ApplicationPolicies.WebSessionIdleTimeout)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'definition' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Default Activity Timeout"
    },
    {
      "Name": "EIDSCA: External Identities - External user leave settings.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.externalIdentitiesPolicy.allowExternalIdentitiesToLeave",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/externalIdentitiesPolicy\" -ApiVersion beta\n        $result.allowExternalIdentitiesToLeave | Should -Be '' -Because \"policies/externalIdentitiesPolicy/allowExternalIdentitiesToLeave should be '' but was $($result.allowExternalIdentitiesToLeave)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/externalIdentitiesPolicy/allowExternalIdentitiesToLeave should be '' but was True, but got $true."
      ],
      "Block": "External Identities"
    },
    {
      "Name": "EIDSCA: External Identities - Deleted Identities Data Removal.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.externalIdentitiesPolicy.allowDeletedIdentitiesDataRemoval",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/externalIdentitiesPolicy\" -ApiVersion beta\n        $result.allowDeletedIdentitiesDataRemoval | Should -Be '' -Because \"policies/externalIdentitiesPolicy/allowDeletedIdentitiesDataRemoval should be '' but was $($result.allowDeletedIdentitiesDataRemoval)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/externalIdentitiesPolicy/allowDeletedIdentitiesDataRemoval should be '' but was False, but got $false."
      ],
      "Block": "External Identities"
    },
    {
      "Name": "EIDSCA: Feature Rollout (Enabled Previews) - .",
      "HelpUrl": "https://maester.dev/test/EIDSCA.featureRolloutPolicies.featureRolloutPolicy",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/featureRolloutPolicies\" -ApiVersion beta\n        $result.value | Should -Be '' -Because \"policies/featureRolloutPolicies/value should be '' but was $($result.value)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'value' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Feature Rollout (Enabled Previews)"
    },
    {
      "Name": "EIDSCA: Authentication Method - General Settings - Manage migration.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.policyMigrationState",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.policyMigrationState | Should -Be 'migrationComplete' -Because \"policies/authenticationMethodsPolicy/policyMigrationState should be 'migrationComplete' but was $($result.policyMigrationState)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/policyMigrationState should be 'migrationComplete' but was migrationInProgress, but they were different.\nExpected length: 17\nActual length:   19\nStrings differ at index 9.\nExpected: 'migrationComplete'\nBut was:  'migrationInProgress'\n           ---------^"
      ],
      "Block": "Authentication Method - General Settings"
    },
    {
      "Name": "EIDSCA: Authentication Method - General Settings - Report suspicious activity - State.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsState",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.reportSuspiciousActivitySettings.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.state should be 'enabled' but was $($result.reportSuspiciousActivitySettings.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.state should be 'enabled' but was default, but they were different.\nString lengths are both 7.\nStrings differ at index 0.\nExpected: 'enabled'\nBut was:  'default'\n           ^"
      ],
      "Block": "Authentication Method - General Settings"
    },
    {
      "Name": "EIDSCA: Authentication Method - General Settings - Report suspicious activity - Included users/groups.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsIncluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.reportSuspiciousActivitySettings.includeTargets.id | Should -Be 'all_users' -Because \"policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.includeTargets.id should be 'all_users' but was $($result.reportSuspiciousActivitySettings.includeTargets.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'includeTargets' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Authentication Method - General Settings"
    },
    {
      "Name": "EIDSCA: Authentication Method - General Settings - Report suspicious activity - Reporting code.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsReporting code",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.reportSuspiciousActivitySettings.voiceReportingCode | Should -Be '' -Because \"policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.voiceReportingCode should be '' but was $($result.reportSuspiciousActivitySettings.voiceReportingCode)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.voiceReportingCode should be '' but was 0, but got 0."
      ],
      "Block": "Authentication Method - General Settings"
    },
    {
      "Name": "EIDSCA: Authentication Method - General Settings - System Credential Preferences - State.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.systemCredentialPreferencesState",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.systemCredentialPreferences.state | Should -Be '' -Because \"policies/authenticationMethodsPolicy/systemCredentialPreferences.state should be '' but was $($result.systemCredentialPreferences.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/systemCredentialPreferences.state should be '' but was enabled, but they were different.\nExpected length: 0\nActual length:   7\nStrings differ at index 0.\nExpected: ''\nBut was:  'enabled'\n           ^"
      ],
      "Block": "Authentication Method - General Settings"
    },
    {
      "Name": "EIDSCA: Authentication Method - General Settings - System Credential Preferences - Included users/groups.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.systemCredentialPreferencesStateIncluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.systemCredentialPreferences.includeTargets.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/systemCredentialPreferences.includeTargets.id should be '' but was $($result.systemCredentialPreferences.includeTargets.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/systemCredentialPreferences.includeTargets.id should be '' but was all_users, but they were different.\nExpected length: 0\nActual length:   9\nStrings differ at index 0.\nExpected: ''\nBut was:  'all_users'\n           ^"
      ],
      "Block": "Authentication Method - General Settings"
    },
    {
      "Name": "EIDSCA: Authentication Method - General Settings - System Credential Preferences - Excluded users/groups.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.systemCredentialPreferencesStateExcluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.systemCredentialPreferences.excludeTargets.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/systemCredentialPreferences.excludeTargets.id should be '' but was $($result.systemCredentialPreferences.excludeTargets.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'id' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Authentication Method - General Settings"
    },
    {
      "Name": "EIDSCA: Authentication Method - General Settings - Registration campaign - State.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignState",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.state | Should -Be '' -Because \"policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.state should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.state should be '' but was default, but they were different.\nExpected length: 0\nActual length:   7\nStrings differ at index 0.\nExpected: ''\nBut was:  'default'\n           ^"
      ],
      "Block": "Authentication Method - General Settings"
    },
    {
      "Name": "EIDSCA: Authentication Method - General Settings - Registration campaign - Included users/groups.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignIncluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.id should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.id should be '' but was all_users, but they were different.\nExpected length: 0\nActual length:   9\nStrings differ at index 0.\nExpected: ''\nBut was:  'all_users'\n           ^"
      ],
      "Block": "Authentication Method - General Settings"
    },
    {
      "Name": "EIDSCA: Authentication Method - General Settings - Registration campaign - Authentication Method.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignTargetedAuthenticationMethod",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.targetedAuthenticationMethod | Should -Be '' -Because \"policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.targetedAuthenticationMethod should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.targetedAuthenticationMethod)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.targetedAuthenticationMethod should be '' but was microsoftAuthenticator, but they were different.\nExpected length: 0\nActual length:   22\nStrings differ at index 0.\nExpected: ''\nBut was:  'microsoftAuthenticator'\n           ^"
      ],
      "Block": "Authentication Method - General Settings"
    },
    {
      "Name": "EIDSCA: Authentication Method - General Settings - Registration campaign - Excluded users/groups.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignExcluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.excludeTargets.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.excludeTargets.id should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.excludeTargets.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "The property 'id' cannot be found on this object. Verify that the property exists."
      ],
      "Block": "Authentication Method - General Settings"
    },
    {
      "Name": "EIDSCA: Authentication Method - General Settings - Registration campaign - Days allowed to snooze.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignSnoozeDurationInDays",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy\" -ApiVersion beta\n        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.snoozeDurationInDays | Should -Be '' -Because \"policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.snoozeDurationInDays should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.snoozeDurationInDays)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.snoozeDurationInDays should be '' but was 7, but got 7."
      ],
      "Block": "Authentication Method - General Settings"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - State.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/state should be 'enabled' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - Allow use of Microsoft Authenticator OTP.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.isSoftwareOathEnabled",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/state should be 'enabled' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - Require number matching for push notifications.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.numberMatchingRequiredState",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.numberMatchingRequiredState.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.state should be 'enabled' but was $($result.featureSettings.numberMatchingRequiredState.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.numberMatchingRequiredStateIncluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.numberMatchingRequiredState.includeTarget.id | Should -Be 'all_users' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.includeTarget.id should be 'all_users' but was $($result.featureSettings.numberMatchingRequiredState.includeTarget.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - Excluded users/groups of number matching for push notifications.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.numberMatchingRequiredStateExcluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.numberMatchingRequiredState.excludeTarget.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.excludeTarget.id should be '' but was $($result.featureSettings.numberMatchingRequiredState.excludeTarget.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.excludeTarget.id should be '' but was 00000000-0000-0000-0000-000000000000, but they were different.\nExpected length: 0\nActual length:   36\nStrings differ at index 0.\nExpected: ''\nBut was:  '00000000-0000-0000-0000-000000000000'\n           ^"
      ],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.displayAppInformationRequiredState",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayAppInformationRequiredState.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.state should be 'enabled' but was $($result.featureSettings.displayAppInformationRequiredState.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.displayAppInformationRequiredStateIncluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayAppInformationRequiredState.includeTarget.id | Should -Be 'all_users' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.includeTarget.id should be 'all_users' but was $($result.featureSettings.displayAppInformationRequiredState.includeTarget.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - Excluded users/groups to show application name in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.displayAppInformationRequiredStateExcluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayAppInformationRequiredState.excludeTarget.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.excludeTarget.id should be '' but was $($result.featureSettings.displayAppInformationRequiredState.excludeTarget.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.excludeTarget.id should be '' but was 00000000-0000-0000-0000-000000000000, but they were different.\nExpected length: 0\nActual length:   36\nStrings differ at index 0.\nExpected: ''\nBut was:  '00000000-0000-0000-0000-000000000000'\n           ^"
      ],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.displayLocationInformationRequiredState",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayLocationInformationRequiredState.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.state should be 'enabled' but was $($result.featureSettings.displayLocationInformationRequiredState.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.displayLocationInformationRequiredStateIncluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayLocationInformationRequiredState.includeTarget.id | Should -Be 'all_users' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.includeTarget.id should be 'all_users' but was $($result.featureSettings.displayLocationInformationRequiredState.includeTarget.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - Excluded users/groups to show geographic location in push and passwordless notifications.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.displayLocationInformationRequiredExcluded",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.featureSettings.displayLocationInformationRequiredState.excludeTarget.id | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.excludeTarget.id should be '' but was $($result.featureSettings.displayLocationInformationRequiredState.excludeTarget.id)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.excludeTarget.id should be '' but was 00000000-0000-0000-0000-000000000000, but they were different.\nExpected length: 0\nActual length:   36\nStrings differ at index 0.\nExpected: ''\nBut was:  '00000000-0000-0000-0000-000000000000'\n           ^"
      ],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - Included users/groups from using Authenticator App.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False; authenticationMode=deviceBasedPush}, but got @{targetType=group; id=all_users; isRegistrationRequired=False; authenticationMode=deviceBasedPush}."
      ],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - Microsoft Authenticator - Excluded users/groups from using Authenticator App.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/excludeTargets should be '' but was, but got $null."
      ],
      "Block": "Authentication Method - Microsoft Authenticator"
    },
    {
      "Name": "EIDSCA: Authentication Method - FIDO2 security key - State.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/state should be 'enabled' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - FIDO2 security key"
    },
    {
      "Name": "EIDSCA: Authentication Method - FIDO2 security key - Allow self-service set up.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.isSelfServiceRegistrationAllowed",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.isSelfServiceRegistrationAllowed | Should -Be 'true' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/isSelfServiceRegistrationAllowed should be 'true' but was $($result.isSelfServiceRegistrationAllowed)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - FIDO2 security key"
    },
    {
      "Name": "EIDSCA: Authentication Method - FIDO2 security key - Enforce attestation.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.isAttestationEnforced",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.isAttestationEnforced | Should -Be 'true' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/isAttestationEnforced should be 'true' but was $($result.isAttestationEnforced)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - FIDO2 security key"
    },
    {
      "Name": "EIDSCA: Authentication Method - FIDO2 security key - Enforce key restrictions.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.keyRestrictions.isEnforced",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.keyRestrictions.isEnforced | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.isEnforced should be '' but was $($result.keyRestrictions.isEnforced)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.isEnforced should be '' but was False, but got $false."
      ],
      "Block": "Authentication Method - FIDO2 security key"
    },
    {
      "Name": "EIDSCA: Authentication Method - FIDO2 security key - Restricted.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.keyRestrictions.aaGuids",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.keyRestrictions.aaGuids | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.aaGuids should be '' but was $($result.keyRestrictions.aaGuids)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.aaGuids should be '' but was, but got $null."
      ],
      "Block": "Authentication Method - FIDO2 security key"
    },
    {
      "Name": "EIDSCA: Authentication Method - FIDO2 security key - Restrict specific keys.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.keyRestrictions.enforcementType",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.keyRestrictions.enforcementType | Should -Be 'block' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.enforcementType should be 'block' but was $($result.keyRestrictions.enforcementType)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - FIDO2 security key"
    },
    {
      "Name": "EIDSCA: Authentication Method - FIDO2 security key - Included users/groups from using security keys.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False; allowedPasskeyProfiles=System.Object[]}, but got @{targetType=group; id=all_users; isRegistrationRequired=False; allowedPasskeyProfiles=System.Object[]}."
      ],
      "Block": "Authentication Method - FIDO2 security key"
    },
    {
      "Name": "EIDSCA: Authentication Method - FIDO2 security key - Excluded users/groups from using security keys.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/excludeTargets should be '' but was, but got $null."
      ],
      "Block": "Authentication Method - FIDO2 security key"
    },
    {
      "Name": "EIDSCA: Authentication Method - Temporary Access Pass - State.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.state | Should -Be 'enabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/state should be 'enabled' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "EIDSCA: Authentication Method - Temporary Access Pass - One-time.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.isUsableOnce",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.isUsableOnce | Should -Be 'false' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/isUsableOnce should be 'false' but was $($result.isUsableOnce)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "EIDSCA: Authentication Method - Temporary Access Pass - Default lifetime.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.defaultLifetimeInMinutes",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.defaultLifetimeInMinutes | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/defaultLifetimeInMinutes should be '' but was $($result.defaultLifetimeInMinutes)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/defaultLifetimeInMinutes should be '' but was 60, but got 60."
      ],
      "Block": "Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "EIDSCA: Authentication Method - Temporary Access Pass - Length.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.defaultLength",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.defaultLength | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/defaultLength should be '' but was $($result.defaultLength)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/defaultLength should be '' but was 8, but got 8."
      ],
      "Block": "Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "EIDSCA: Authentication Method - Temporary Access Pass - Minimum lifetime.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.minimumLifetimeInMinutes",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.minimumLifetimeInMinutes | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/minimumLifetimeInMinutes should be '' but was $($result.minimumLifetimeInMinutes)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/minimumLifetimeInMinutes should be '' but was 60, but got 60."
      ],
      "Block": "Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "EIDSCA: Authentication Method - Temporary Access Pass - Maximum lifetime.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.maximumLifetimeInMinutes",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.maximumLifetimeInMinutes | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/maximumLifetimeInMinutes should be '' but was $($result.maximumLifetimeInMinutes)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/maximumLifetimeInMinutes should be '' but was 480, but got 480."
      ],
      "Block": "Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "EIDSCA: Authentication Method - Temporary Access Pass - Included users/groups from Temporary Access Pass.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False}, but got @{targetType=group; id=all_users; isRegistrationRequired=False}."
      ],
      "Block": "Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "EIDSCA: Authentication Method - Temporary Access Pass - Excluded users/group from Temporary Access Pass.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/excludeTargets should be '' but was, but got $null."
      ],
      "Block": "Authentication Method - Temporary Access Pass"
    },
    {
      "Name": "EIDSCA: Authentication Method - Third-party software OATH tokens - State.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')\" -ApiVersion beta\n        $result.state | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/state should be '' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/state should be '' but was disabled, but they were different.\nExpected length: 0\nActual length:   8\nStrings differ at index 0.\nExpected: ''\nBut was:  'disabled'\n           ^"
      ],
      "Block": "Authentication Method - Third-party software OATH tokens"
    },
    {
      "Name": "EIDSCA: Authentication Method - Third-party software OATH tokens - Included users/groups from OATH token.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False}, but got @{targetType=group; id=all_users; isRegistrationRequired=False}."
      ],
      "Block": "Authentication Method - Third-party software OATH tokens"
    },
    {
      "Name": "EIDSCA: Authentication Method - Third-party software OATH tokens - Excluded users/group from OATH token.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/excludeTargets should be '' but was, but got $null."
      ],
      "Block": "Authentication Method - Third-party software OATH tokens"
    },
    {
      "Name": "EIDSCA: Authentication Method - Email OTP - State.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')\" -ApiVersion beta\n        $result.state | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/state should be '' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/state should be '' but was disabled, but they were different.\nExpected length: 0\nActual length:   8\nStrings differ at index 0.\nExpected: ''\nBut was:  'disabled'\n           ^"
      ],
      "Block": "Authentication Method - Email OTP"
    },
    {
      "Name": "EIDSCA: Authentication Method - Email OTP - Allow external users to use email OTP.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.allowExternalIdToUseEmailOtp",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')\" -ApiVersion beta\n        $result.allowExternalIdToUseEmailOtp | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/allowExternalIdToUseEmailOtp should be '' but was $($result.allowExternalIdToUseEmailOtp)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/allowExternalIdToUseEmailOtp should be '' but was disabled, but they were different.\nExpected length: 0\nActual length:   8\nStrings differ at index 0.\nExpected: ''\nBut was:  'disabled'\n           ^"
      ],
      "Block": "Authentication Method - Email OTP"
    },
    {
      "Name": "EIDSCA: Authentication Method - Email OTP - Included users/groups from Email OTP.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/includeTargets should be '' but was, but got $null."
      ],
      "Block": "Authentication Method - Email OTP"
    },
    {
      "Name": "EIDSCA: Authentication Method - Email OTP - Excluded users/group from Email OTP.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/excludeTargets should be '' but was, but got $null."
      ],
      "Block": "Authentication Method - Email OTP"
    },
    {
      "Name": "EIDSCA: Authentication Method - Voice call - State.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Passed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')\" -ApiVersion beta\n        $result.state | Should -Be 'disabled' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/state should be 'disabled' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Authentication Method - Voice call"
    },
    {
      "Name": "EIDSCA: Authentication Method - Voice call - Phone Options - Office.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.isOfficePhoneAllowed",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')\" -ApiVersion beta\n        $result.isOfficePhoneAllowed | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/isOfficePhoneAllowed should be '' but was $($result.isOfficePhoneAllowed)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/isOfficePhoneAllowed should be '' but was False, but got $false."
      ],
      "Block": "Authentication Method - Voice call"
    },
    {
      "Name": "EIDSCA: Authentication Method - Voice call - Included users/groups from Voice call.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False}, but got @{targetType=group; id=all_users; isRegistrationRequired=False}."
      ],
      "Block": "Authentication Method - Voice call"
    },
    {
      "Name": "EIDSCA: Authentication Method - Voice call - Excluded users/group from Voice call.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/excludeTargets should be '' but was, but got $null."
      ],
      "Block": "Authentication Method - Voice call"
    },
    {
      "Name": "EIDSCA: Authentication Method - SMS - State.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')\" -ApiVersion beta\n        $result.state | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/state should be '' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/state should be '' but was enabled, but they were different.\nExpected length: 0\nActual length:   7\nStrings differ at index 0.\nExpected: ''\nBut was:  'enabled'\n           ^"
      ],
      "Block": "Authentication Method - SMS"
    },
    {
      "Name": "EIDSCA: Authentication Method - SMS - Included users/groups from Voice call.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False; isUsableForSignIn=False}, but got @{targetType=group; id=all_users; isRegistrationRequired=False; isUsableForSignIn=False}."
      ],
      "Block": "Authentication Method - SMS"
    },
    {
      "Name": "EIDSCA: Authentication Method - SMS - Excluded users/group from Voice call.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/excludeTargets should be '' but was, but got $null."
      ],
      "Block": "Authentication Method - SMS"
    },
    {
      "Name": "EIDSCA: Authentication Method - Certificate-based authentication - State.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')\" -ApiVersion beta\n        $result.state | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/state should be '' but was $($result.state)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/state should be '' but was disabled, but they were different.\nExpected length: 0\nActual length:   8\nStrings differ at index 0.\nExpected: ''\nBut was:  'disabled'\n           ^"
      ],
      "Block": "Authentication Method - Certificate-based authentication"
    },
    {
      "Name": "EIDSCA: Authentication Method - Certificate-based authentication - Included users/groups from CBA.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')\" -ApiVersion beta\n        $result.includeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/includeTargets should be '' but was $($result.includeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/includeTargets should be '' but was @{targetType=group; id=all_users; isRegistrationRequired=False}, but got @{targetType=group; id=all_users; isRegistrationRequired=False}."
      ],
      "Block": "Authentication Method - Certificate-based authentication"
    },
    {
      "Name": "EIDSCA: Authentication Method - Certificate-based authentication - Excluded users/group from CBA.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')\" -ApiVersion beta\n        $result.excludeTargets | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/excludeTargets should be '' but was $($result.excludeTargets)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/excludeTargets should be '' but was, but got $null."
      ],
      "Block": "Authentication Method - Certificate-based authentication"
    },
    {
      "Name": "EIDSCA: Authentication Method - Certificate-based authentication - Authentication binding - Protected Level.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')\" -ApiVersion beta\n        $result.authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode should be '' but was $($result.authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected strings to be the same, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode should be '' but was x509CertificateSingleFactor, but they were different.\nExpected length: 0\nActual length:   27\nStrings differ at index 0.\nExpected: ''\nBut was:  'x509CertificateSingleFactor'\n           ^"
      ],
      "Block": "Authentication Method - Certificate-based authentication"
    },
    {
      "Name": "EIDSCA: Authentication Method - Certificate-based authentication - Authentication binding - Rules.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationModeConfiguration.rules",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')\" -ApiVersion beta\n        $result.authenticationModeConfiguration.rules | Should -Be '' -Because \"policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/authenticationModeConfiguration.rules should be '' but was $($result.authenticationModeConfiguration.rules)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/authenticationModeConfiguration.rules should be '' but was, but got $null."
      ],
      "Block": "Authentication Method - Certificate-based authentication"
    },
    {
      "Name": "EIDSCA: Consent Framework - Admin Consent Request (Coming soon) - Users can request admin consent to apps they are unable to consent to.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.servicePrincipalCreationPolicies.isEnabled",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.isEnabled | Should -Be 'true' -Because \"policies/adminConsentRequestPolicy/isEnabled should be 'true' but was $($result.isEnabled)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'true', because policies/adminConsentRequestPolicy/isEnabled should be 'true' but was False, but got $false."
      ],
      "Block": "Consent Framework - Admin Consent Request (Coming soon)"
    },
    {
      "Name": "EIDSCA: Consent Framework - Admin Consent Request (Coming soon) - Reviewers will receive email notifications for requests???.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.servicePrincipalCreationPolicies.notifyReviewers",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.notifyReviewers | Should -Be 'true' -Because \"policies/adminConsentRequestPolicy/notifyReviewers should be 'true' but was $($result.notifyReviewers)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'true', because policies/adminConsentRequestPolicy/notifyReviewers should be 'true' but was False, but got $false."
      ],
      "Block": "Consent Framework - Admin Consent Request (Coming soon)"
    },
    {
      "Name": "EIDSCA: Consent Framework - Admin Consent Request (Coming soon) - Reviewers will receive email notifications when admin consent requests are about to expire???.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.servicePrincipalCreationPolicies.notifyReviewers",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.notifyReviewers | Should -Be 'true' -Because \"policies/adminConsentRequestPolicy/notifyReviewers should be 'true' but was $($result.notifyReviewers)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected 'true', because policies/adminConsentRequestPolicy/notifyReviewers should be 'true' but was False, but got $false."
      ],
      "Block": "Consent Framework - Admin Consent Request (Coming soon)"
    },
    {
      "Name": "EIDSCA: Consent Framework - Admin Consent Request (Coming soon) - Consent request expires after (days)???.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.servicePrincipalCreationPolicies.requestDurationInDays",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.requestDurationInDays | Should -Be '30' -Because \"policies/adminConsentRequestPolicy/requestDurationInDays should be '30' but was $($result.requestDurationInDays)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected '30', because policies/adminConsentRequestPolicy/requestDurationInDays should be '30' but was 0, but got 0."
      ],
      "Block": "Consent Framework - Admin Consent Request (Coming soon)"
    },
    {
      "Name": "EIDSCA: Consent Framework - Admin Consent Request (Coming soon) - Consent request expires after (days)???.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.servicePrincipalCreationPolicies.reviewers",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.reviewers | Should -Be '30' -Because \"policies/adminConsentRequestPolicy/reviewers should be '30' but was $($result.reviewers)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected '30', because policies/adminConsentRequestPolicy/reviewers should be '30' but was, but got $null."
      ],
      "Block": "Consent Framework - Admin Consent Request (Coming soon)"
    },
    {
      "Name": "EIDSCA: Consent Framework - Admin Consent Request (Coming soon) - Consent request expires after (days)???.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.servicePrincipalCreationPolicies.version",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"policies/adminConsentRequestPolicy\" -ApiVersion beta\n        $result.version | Should -Be '' -Because \"policies/adminConsentRequestPolicy/version should be '' but was $($result.version)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "Expected <empty>, because policies/adminConsentRequestPolicy/version should be '' but was 0, but got 0."
      ],
      "Block": "Consent Framework - Admin Consent Request (Coming soon)"
    },
    {
      "Name": "EIDSCA: Azure AD Recommendations - Protect all users with a user risk policy.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.recommendations.Microsoft.Identity.IAM.Insights.UserRiskPolicy",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"directory/recommendations\" -ApiVersion beta\n        $result.status | Should -Be 'completedBySystem' -Because \"directory/recommendations/status should be 'completedBySystem' but was $($result.status)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "GET https://graph.microsoft.com/beta/directory/recommendations\r\nHTTP/2.0 403 Forbidden\r\nVary: Accept-Encoding\r\nStrict-Transport-Security: max-age=31536000\r\nrequest-id: 191e65ae-df99-4428-9f02-b879d472b2fc\r\nclient-request-id: 93f292b7-3768-44d9-8cfd-1b1354ee91a8\r\nx-ms-ags-diagnostic: {\"ServerInfo\":{\"DataCenter\":\"Australia Southeast\",\"Slice\":\"E\",\"Ring\":\"4\",\"ScaleUnit\":\"002\",\"RoleInstance\":\"ML1PEPF00004B00\"}}\r\nDate: Fri, 22 Mar 2024 10:40:40 GMT\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\n\r\n{\"error\":{\"code\":\"Authentication_MSGraphPermissionMissing\",\"message\":\"Calling principal does not have required MSGraph permissions DirectoryRecommendations.Read.All,DirectoryRecommendations.ReadWrite.All\",\"innerError\":{\"date\":\"2024-03-22T10:40:41\",\"request-id\":\"191e65ae-df99-4428-9f02-b879d472b2fc\",\"client-request-id\":\"93f292b7-3768-44d9-8cfd-1b1354ee91a8\"}}}"
      ],
      "Block": "Azure AD Recommendations"
    },
    {
      "Name": "EIDSCA: Azure AD Recommendations - Protect all users with a sign-in risk policy.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.recommendations.Microsoft.Identity.IAM.Insights.SigninRiskPolicy",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"directory/recommendations\" -ApiVersion beta\n        $result.status | Should -Be 'completedBySystem' -Because \"directory/recommendations/status should be 'completedBySystem' but was $($result.status)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "GET https://graph.microsoft.com/beta/directory/recommendations\r\nHTTP/2.0 403 Forbidden\r\nVary: Accept-Encoding\r\nStrict-Transport-Security: max-age=31536000\r\nrequest-id: 0352efbd-b312-4d02-8cfc-288964b5b5e7\r\nclient-request-id: 6ec5b28a-89aa-4354-aff6-e165bde6d16a\r\nx-ms-ags-diagnostic: {\"ServerInfo\":{\"DataCenter\":\"Australia Southeast\",\"Slice\":\"E\",\"Ring\":\"4\",\"ScaleUnit\":\"002\",\"RoleInstance\":\"ML1PEPF00004B00\"}}\r\nDate: Fri, 22 Mar 2024 10:40:40 GMT\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\n\r\n{\"error\":{\"code\":\"Authentication_MSGraphPermissionMissing\",\"message\":\"Calling principal does not have required MSGraph permissions DirectoryRecommendations.Read.All,DirectoryRecommendations.ReadWrite.All\",\"innerError\":{\"date\":\"2024-03-22T10:40:41\",\"request-id\":\"0352efbd-b312-4d02-8cfc-288964b5b5e7\",\"client-request-id\":\"6ec5b28a-89aa-4354-aff6-e165bde6d16a\"}}}"
      ],
      "Block": "Azure AD Recommendations"
    },
    {
      "Name": "EIDSCA: Azure AD Recommendations - Require multifactor authentication for administrative roles.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.recommendations.Microsoft.Identity.IAM.Insights.AdminMFAV2",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"directory/recommendations\" -ApiVersion beta\n        $result.status | Should -Be 'completedBySystem' -Because \"directory/recommendations/status should be 'completedBySystem' but was $($result.status)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "GET https://graph.microsoft.com/beta/directory/recommendations\r\nHTTP/2.0 403 Forbidden\r\nVary: Accept-Encoding\r\nStrict-Transport-Security: max-age=31536000\r\nrequest-id: 4ef26003-0455-4cc0-b87b-adc58bfa1e09\r\nclient-request-id: 6d371bf0-8577-43e8-b546-994cfd94ed65\r\nx-ms-ags-diagnostic: {\"ServerInfo\":{\"DataCenter\":\"Australia Southeast\",\"Slice\":\"E\",\"Ring\":\"4\",\"ScaleUnit\":\"002\",\"RoleInstance\":\"ML1PEPF00004B00\"}}\r\nDate: Fri, 22 Mar 2024 10:40:41 GMT\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\n\r\n{\"error\":{\"code\":\"Authentication_MSGraphPermissionMissing\",\"message\":\"Calling principal does not have required MSGraph permissions DirectoryRecommendations.Read.All,DirectoryRecommendations.ReadWrite.All\",\"innerError\":{\"date\":\"2024-03-22T10:40:41\",\"request-id\":\"4ef26003-0455-4cc0-b87b-adc58bfa1e09\",\"client-request-id\":\"6d371bf0-8577-43e8-b546-994cfd94ed65\"}}}"
      ],
      "Block": "Azure AD Recommendations"
    },
    {
      "Name": "EIDSCA: Azure AD Recommendations - Use limited administrative roles.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.recommendations.Microsoft.Identity.IAM.Insights.RoleOverlap",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"directory/recommendations\" -ApiVersion beta\n        $result.status | Should -Be 'completedBySystem' -Because \"directory/recommendations/status should be 'completedBySystem' but was $($result.status)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "GET https://graph.microsoft.com/beta/directory/recommendations\r\nHTTP/2.0 403 Forbidden\r\nVary: Accept-Encoding\r\nStrict-Transport-Security: max-age=31536000\r\nrequest-id: f6b530ab-dbbb-4dc2-a137-bd98128a630b\r\nclient-request-id: 8a59460e-b282-486e-94de-de49512106b3\r\nx-ms-ags-diagnostic: {\"ServerInfo\":{\"DataCenter\":\"Australia Southeast\",\"Slice\":\"E\",\"Ring\":\"4\",\"ScaleUnit\":\"002\",\"RoleInstance\":\"ML1PEPF00004B00\"}}\r\nDate: Fri, 22 Mar 2024 10:40:41 GMT\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\n\r\n{\"error\":{\"code\":\"Authentication_MSGraphPermissionMissing\",\"message\":\"Calling principal does not have required MSGraph permissions DirectoryRecommendations.Read.All,DirectoryRecommendations.ReadWrite.All\",\"innerError\":{\"date\":\"2024-03-22T10:40:41\",\"request-id\":\"f6b530ab-dbbb-4dc2-a137-bd98128a630b\",\"client-request-id\":\"8a59460e-b282-486e-94de-de49512106b3\"}}}"
      ],
      "Block": "Azure AD Recommendations"
    },
    {
      "Name": "EIDSCA: Azure AD Recommendations - Remove unused applications.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.recommendations.Microsoft.Identity.IAM.Insights.StaleApps",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"directory/recommendations\" -ApiVersion beta\n        $result.status | Should -Be 'completedBySystem' -Because \"directory/recommendations/status should be 'completedBySystem' but was $($result.status)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "GET https://graph.microsoft.com/beta/directory/recommendations\r\nHTTP/2.0 403 Forbidden\r\nVary: Accept-Encoding\r\nStrict-Transport-Security: max-age=31536000\r\nrequest-id: 7f6aefb0-a40a-4dd1-ba42-bfa2f2190c1c\r\nclient-request-id: c8b6faaa-3716-47d5-82b0-2f104071f4a4\r\nx-ms-ags-diagnostic: {\"ServerInfo\":{\"DataCenter\":\"Australia Southeast\",\"Slice\":\"E\",\"Ring\":\"4\",\"ScaleUnit\":\"002\",\"RoleInstance\":\"ML1PEPF00004B00\"}}\r\nDate: Fri, 22 Mar 2024 10:40:41 GMT\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\n\r\n{\"error\":{\"code\":\"Authentication_MSGraphPermissionMissing\",\"message\":\"Calling principal does not have required MSGraph permissions DirectoryRecommendations.Read.All,DirectoryRecommendations.ReadWrite.All\",\"innerError\":{\"date\":\"2024-03-22T10:40:41\",\"request-id\":\"7f6aefb0-a40a-4dd1-ba42-bfa2f2190c1c\",\"client-request-id\":\"c8b6faaa-3716-47d5-82b0-2f104071f4a4\"}}}"
      ],
      "Block": "Azure AD Recommendations"
    },
    {
      "Name": "EIDSCA: Azure AD Recommendations - Renew expiring application credentials.",
      "HelpUrl": "https://maester.dev/test/EIDSCA.recommendations.Microsoft.Identity.IAM.Insights.ApplicationCredentialExpiry",
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Invoke-MtGraphRequest -RelativeUri \"directory/recommendations\" -ApiVersion beta\n        $result.status | Should -Be 'completedBySystem' -Because \"directory/recommendations/status should be 'completedBySystem' but was $($result.status)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",
      "ErrorRecord": [
        "GET https://graph.microsoft.com/beta/directory/recommendations\r\nHTTP/2.0 403 Forbidden\r\nVary: Accept-Encoding\r\nStrict-Transport-Security: max-age=31536000\r\nrequest-id: 77560590-6fce-477d-82b6-09048f5783fe\r\nclient-request-id: efd8d997-eca5-4beb-8c11-153036868f85\r\nx-ms-ags-diagnostic: {\"ServerInfo\":{\"DataCenter\":\"Australia Southeast\",\"Slice\":\"E\",\"Ring\":\"4\",\"ScaleUnit\":\"002\",\"RoleInstance\":\"ML1PEPF00004B00\"}}\r\nDate: Fri, 22 Mar 2024 10:40:41 GMT\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\n\r\n{\"error\":{\"code\":\"Authentication_MSGraphPermissionMissing\",\"message\":\"Calling principal does not have required MSGraph permissions DirectoryRecommendations.Read.All,DirectoryRecommendations.ReadWrite.All\",\"innerError\":{\"date\":\"2024-03-22T10:40:41\",\"request-id\":\"77560590-6fce-477d-82b6-09048f5783fe\",\"client-request-id\":\"efd8d997-eca5-4beb-8c11-153036868f85\"}}}"
      ],
      "Block": "Azure AD Recommendations"
    },
    {
      "Name": "MT.1002: App management restrictions on applications and service principals is configured and enabled.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1002",
      "Tag": [
        "App",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtAppManagementPolicyEnabled | Should -Be $true -Because \"an app policy for workload identities should be defined to enforce strong credentials instead of passwords and a maximum expiry period (e.g. credential should be renewed every six months)\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-AppManagementPolicies.Tests.ps1",
      "ErrorRecord": [],
      "Block": "App Management Policies"
    },
    {
      "Name": "MT.1001: At least one Conditional Access policy is configured with device compliance.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1001",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaDeviceComplianceExists | Should -Be $true -Because \"there is no policy which requires device compliances\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1003: At least one Conditional Access policy is configured with All Apps.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1003",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists -SkipCheckAllUsers | Should -Be $true -Because \"there is no policy scoped to All Apps\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1004: At least one Conditional Access policy is configured with All Apps and All Users.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1004",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists | Should -Be $true -Because \"there is no policy scoped to All Apps and All Users\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1005: All Conditional Access policies are configured to exclude at least one emergency/break glass account or group.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1005",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaEmergencyAccessExists | Should -Be $true -Because \"there is no emergency access account or group present in all enabled policies\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1006: At least one Conditional Access policy is configured to require MFA for admins.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1006",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists | Should -Be $true -Because \"there is no policy that requires MFA for admins\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1007: At least one Conditional Access policy is configured to require MFA for all users.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1007",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaMfaForAllUsers | Should -Be $true -Because \"there is no policy that requires MFA for all users\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1008: At least one Conditional Access policy is configured to require MFA for Azure management.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1008",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaMfaForAdminManagement | Should -Be $true -Because \"there is no policy that requires MFA for Azure management\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1009: At least one Conditional Access policy is configured to block other legacy authentication.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1009",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaBlockLegacyOtherAuthentication | Should -Be $true -Because \"there is no policy that blocks legacy authentication\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1010: At least one Conditional Access policy is configured to block legacy authentication for Exchange ActiveSync.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1010",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaBlockLegacyExchangeActiveSyncAuthentication | Should -Be $true -Because \"there is no policy that blocks legacy authentication for Exchange ActiveSync\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1011: At least one Conditional Access policy is configured to secure security info registration only from a trusted location.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1011",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaSecureSecurityInfoRegistration | Should -Be $true -Because \"there is no policy that secures security info registration\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1012: At least one Conditional Access policy is configured to require MFA for risky sign-ins.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1012",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaMfaForRiskySignIns | Should -Be $true -Because \"there is no policy that requires MFA for risky sign-ins\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1013: At least one Conditional Access policy is configured to require new password when user risk is high.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1013",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaRequirePasswordChangeForHighUserRisk | Should -Be $true -Because \"there is no policy that requires new password when user risk is high\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1014: At least one Conditional Access policy is configured to require compliant or Entra hybrid joined devices for admins.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1014",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaDeviceComplianceAdminsExists | Should -Be $true -Because \"there is no policy that requires compliant or Entra hybrid joined devices for admins\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1015: At least one Conditional Access policy is configured to block access for unknown or unsupported device platforms.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1015",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaBlockUnknownOrUnsupportedDevicePlatforms | Should -Be $true -Because \"there is no policy that blocks access for unknown or unsupported device platforms\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1016: At least one Conditional Access policy is configured to require MFA for guest access.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1016",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaMfaForGuests | Should -Be $true -Because \"there is no policy that requires MFA for guest access\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1017: At least one Conditional Access policy is configured to enforce non persistent browser session for non-corporate devices.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1017",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaEnforceNonPersistentBrowserSession | Should -Be $true -Because \"there is no policy that enforces non persistent browser session for non-corporate devices\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1018: At least one Conditional Access policy is configured to enforce sign-in frequency for non-corporate devices.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1018",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaEnforceSignInFrequency | Should -Be $true -Because \"there is no policy that enforces sign-in frequency for non-corporate devices\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1019: At least one Conditional Access policy is configured to enable application enforced restrictions.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1019",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaApplicationEnforcedRestrictions | Should -Be $true -Because \"there is no policy that enables application enforced restrictions\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1020: All Conditional Access policies are configured to exclude directory synchronization accounts or do not scope them.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1020",
      "Tag": [
        "CA",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        Test-MtCaExclusionForDirectorySyncAccounts | Should -Be $true -Because \"there is no policy that excludes directory synchronization accounts\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-ConditionalAccessBaseline.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Conditional Access Baseline Policies"
    },
    {
      "Name": "MT.1021: No external user with permanent and high-privileges in Entra ID.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1021",
      "Tag": [
        "Privileged",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        $Check = Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel \"ControlPlane\" -FilterPrincipal \"ExternalUser\"\n        $Check.Finding | Should -Be $false -Because \"External user shouldn't have high-privileged roles\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-PrivilegedAssignments.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Directory Roles - Permanent assignments"
    },
    {
      "Name": "MT.1022: No hybrid user with permanent and Control Plane assignment to Control Plane role.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1022",
      "Tag": [
        "Privileged",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        $Check = Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel \"ControlPlane\" -FilterPrincipal \"HybridUser\"\n        $Check.Finding | Should -Be $false -Because \"Hybrid user with access to high-privileged directory roles which should be avoided\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-PrivilegedAssignments.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Directory Roles - Permanent assignments"
    },
    {
      "Name": "MT.1023: No Service Principal with Client Secret and permanent assignment to Control Plane role.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1023",
      "Tag": [
        "Privileged",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        $Check = Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel \"ControlPlane\" -FilterPrincipal \"ServicePrincipalClientSecret\"\n        $Check.Finding | Should -Be $false -Because \"Service Principal with assignments to high-privileged roles should not using Client Secret\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-PrivilegedAssignments.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Directory Roles - Permanent assignments"
    },
    {
      "Name": "MT.1024: No user with mailbox and permanent assignment to Control Plane role.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1024",
      "Tag": [
        "Privileged",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        $Check = Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel \"ControlPlane\" -FilterPrincipal \"UserMailbox\"\n        $Check.Finding | Should -Be $false -Because \"Privileged user with assignment to high-privileged roles should not be mail-enabled which could be a risk for phishing attacks\"\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-PrivilegedAssignments.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Directory Roles - Permanent assignments"
    },
    {
      "Name": "MT.1025: Stale accounts are not assigned to privileged roles.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1025",
      "Tag": [
        "Privileged",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        $Check = Test-MtPimAlertsExists -AlertId \"StaleSignInAlert\"\n        $check.numberOfAffectedItems -eq \"0\" | Should -Be $true -Because $check.securityImpact\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-PrivilegedAssignments.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Privileged Identity Management - Eligible assignments"
    },
    {
      "Name": "MT.1026: Eligible role assignments on Control Plane are in use by administrators.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1026",
      "Tag": [
        "Privileged",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        $Check = Test-MtPimAlertsExists -AlertId \"RedundantAssignmentAlert\" -FilteredAccessLevel \"ControlPlane\"\n        $check.numberOfAffectedItems -eq \"0\" | Should -Be $true -Because $check.securityImpact\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-PrivilegedAssignments.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Privileged Identity Management - Eligible assignments"
    },
    {
      "Name": "MT.1027: Privileged role on Control Plane are by PIM only.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1027",
      "Tag": [
        "Privileged",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        $Check = Test-MtPimAlertsExists -AlertId \"RolesAssignedOutsidePimAlert\" -FilteredAccessLevel \"ControlPlane\"\n        $check.numberOfAffectedItems -eq \"0\" | Should -Be $true -Because $check.securityImpact\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-PrivilegedAssignments.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Privileged Identity Management - Eligible assignments"
    },
    {
      "Name": "MT.1028: Limited number of Global Admins are assigned.",
      "HelpUrl": "https://maester.dev/docs/tests/MT.1028",
      "Tag": [
        "Privileged",
        "Security",
        "All"
      ],
      "Result": "NotRun",
      "ScriptBlock": "\n        $Check = Test-MtPimAlertsExists -AlertId \"TooManyGlobalAdminsAssignedToTenantAlert\"\n        $check.numberOfAffectedItems -eq \"0\" | Should -Be $true -Because $check.securityImpact\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Test-PrivilegedAssignments.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Privileged Identity Management - Eligible assignments"
    }
  ],
  "Blocks": [
    {
      "Name": "Default Authorization Settings",
      "Result": "Failed",
      "FailedCount": 11,
      "PassedCount": 3,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 14,
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ]
    },
    {
      "Name": "Default Settings - Consent Policy Settings",
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
      "Name": "Default Settings - Password Rule Settings",
      "Result": "Failed",
      "FailedCount": 6,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 6,
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ]
    },
    {
      "Name": "Default Settings - Classification and M365 Groups",
      "Result": "Failed",
      "FailedCount": 14,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 14,
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ]
    },
    {
      "Name": "Default Activity Timeout",
      "Result": "Failed",
      "FailedCount": 1,
      "PassedCount": 0,
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
      "Name": "External Identities",
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
      "Name": "Feature Rollout (Enabled Previews)",
      "Result": "Failed",
      "FailedCount": 1,
      "PassedCount": 0,
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
      "Name": "Authentication Method - General Settings",
      "Result": "Failed",
      "FailedCount": 12,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 12,
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ]
    },
    {
      "Name": "Authentication Method - Microsoft Authenticator",
      "Result": "Failed",
      "FailedCount": 5,
      "PassedCount": 8,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 13,
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ]
    },
    {
      "Name": "Authentication Method - FIDO2 security key",
      "Result": "Failed",
      "FailedCount": 4,
      "PassedCount": 4,
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
      "Name": "Authentication Method - Temporary Access Pass",
      "Result": "Failed",
      "FailedCount": 6,
      "PassedCount": 2,
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
      "Name": "Authentication Method - Third-party software OATH tokens",
      "Result": "Failed",
      "FailedCount": 3,
      "PassedCount": 0,
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
      "Name": "Authentication Method - Email OTP",
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
      "Name": "Authentication Method - Voice call",
      "Result": "Failed",
      "FailedCount": 3,
      "PassedCount": 1,
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
      "Name": "Authentication Method - SMS",
      "Result": "Failed",
      "FailedCount": 3,
      "PassedCount": 0,
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
      "Name": "Authentication Method - Certificate-based authentication",
      "Result": "Failed",
      "FailedCount": 5,
      "PassedCount": 0,
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
      "Name": "Consent Framework - Admin Consent Request (Coming soon)",
      "Result": "Failed",
      "FailedCount": 6,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 6,
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ]
    },
    {
      "Name": "Azure AD Recommendations",
      "Result": "Failed",
      "FailedCount": 6,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 6,
      "Tag": [
        "EIDSCA",
        "Security",
        "All"
      ]
    },
    {
      "Name": "App Management Policies",
      "Result": "NotRun",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 0,
      "Tag": [
        "App",
        "Security",
        "All"
      ]
    },
    {
      "Name": "Conditional Access Baseline Policies",
      "Result": "NotRun",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 0,
      "Tag": [
        "CA",
        "Security",
        "All"
      ]
    },
    {
      "Name": "Directory Roles - Permanent assignments",
      "Result": "NotRun",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 0,
      "Tag": [
        "Privileged",
        "Security",
        "All"
      ]
    },
    {
      "Name": "Privileged Identity Management - Eligible assignments",
      "Result": "NotRun",
      "FailedCount": 0,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 0,
      "Tag": [
        "Privileged",
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
