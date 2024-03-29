BeforeDiscovery {
    $AvailablePlans = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/organization" | Select-Object -ExpandProperty value | Select-Object -ExpandProperty assignedPlans | Where-Object service -EQ "AADPremiumService" | Select-Object -ExpandProperty servicePlanId
    if ( "eec0eb4f-6444-4f95-aba0-50c24d67f998" -in $AvailablePlans ) {
        $EntraIDPlan = "P2"
    } elseif ( "41781fb2-bc02-4b7c-bd55-b576c07bb09d)" -in $AvailablePlans ) {
        $EntraIDPlan = "P1"
    } else {
        $EntraIDPlan = "Free"
    }
}

Describe "Conditional Access Baseline Policies" -Tag "CA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MT.1001: At least one Conditional Access policy is configured with device compliance. See https://maester.dev/docs/tests/MT.1001" {
        Test-MtCaDeviceComplianceExists | Should -Be $true -Because "there is no policy which requires device compliances"
    }
    It "MT.1003: At least one Conditional Access policy is configured with All Apps. See https://maester.dev/docs/tests/MT.1003" {
        Test-MtCaAllAppsExists -SkipCheckAllUsers | Should -Be $true -Because "there is no policy scoped to All Apps"
    }
    It "MT.1004: At least one Conditional Access policy is configured with All Apps and All Users. See https://maester.dev/docs/tests/MT.1004" {
        Test-MtCaAllAppsExists | Should -Be $true -Because "there is no policy scoped to All Apps and All Users"
    }
    It "MT.1005: All Conditional Access policies are configured to exclude at least one emergency/break glass account or group. See https://maester.dev/docs/tests/MT.1005" {
        Test-MtCaEmergencyAccessExists | Should -Be $true -Because "there is no emergency access account or group present in all enabled policies"
    }
    It "MT.1006: At least one Conditional Access policy is configured to require MFA for admins. See https://maester.dev/docs/tests/MT.1006" {
        Test-MtCaAllAppsExists | Should -Be $true -Because "there is no policy that requires MFA for admins"
    }
    It "MT.1007: At least one Conditional Access policy is configured to require MFA for all users. See https://maester.dev/docs/tests/MT.1007" {
        Test-MtCaMfaForAllUsers | Should -Be $true -Because "there is no policy that requires MFA for all users"
    }
    It "MT.1008: At least one Conditional Access policy is configured to require MFA for Azure management. See https://maester.dev/docs/tests/MT.1008" {
        Test-MtCaMfaForAdminManagement | Should -Be $true -Because "there is no policy that requires MFA for Azure management"
    }
    It "MT.1009: At least one Conditional Access policy is configured to block other legacy authentication. See https://maester.dev/docs/tests/MT.1009" {
        Test-MtCaBlockLegacyOtherAuthentication | Should -Be $true -Because "there is no policy that blocks legacy authentication"
    }
    It "MT.1010: At least one Conditional Access policy is configured to block legacy authentication for Exchange ActiveSync. See https://maester.dev/docs/tests/MT.1010" {
        Test-MtCaBlockLegacyExchangeActiveSyncAuthentication | Should -Be $true -Because "there is no policy that blocks legacy authentication for Exchange ActiveSync"
    }
    It "MT.1011: At least one Conditional Access policy is configured to secure security info registration only from a trusted location. See https://maester.dev/docs/tests/MT.1011" {
        Test-MtCaSecureSecurityInfoRegistration | Should -Be $true -Because "there is no policy that secures security info registration"
    }
    It "MT.1012: At least one Conditional Access policy is configured to require MFA for risky sign-ins. See https://maester.dev/docs/tests/MT.1012" -Skip:( $EntraIDPlan -eq "P1" ) {
        Test-MtCaMfaForRiskySignIn | Should -Be $true -Because "there is no policy that requires MFA for risky sign-ins"
    }
    It "MT.1013: At least one Conditional Access policy is configured to require new password when user risk is high. See https://maester.dev/docs/tests/MT.1013" -Skip:( $EntraIDPlan -eq "P1" ) {
        Test-MtCaRequirePasswordChangeForHighUserRisk | Should -Be $true -Because "there is no policy that requires new password when user risk is high"
    }
    It "MT.1014: At least one Conditional Access policy is configured to require compliant or Entra hybrid joined devices for admins. See https://maester.dev/docs/tests/MT.1014" {
        Test-MtCaDeviceComplianceAdminsExists | Should -Be $true -Because "there is no policy that requires compliant or Entra hybrid joined devices for admins"
    }
    It "MT.1015: At least one Conditional Access policy is configured to block access for unknown or unsupported device platforms. See https://maester.dev/docs/tests/MT.1015" {
        Test-MtCaBlockUnknownOrUnsupportedDevicePlatform | Should -Be $true -Because "there is no policy that blocks access for unknown or unsupported device platforms"
    }
    It "MT.1016: At least one Conditional Access policy is configured to require MFA for guest access. See https://maester.dev/docs/tests/MT.1016" {
        Test-MtCaMfaForGuest | Should -Be $true -Because "there is no policy that requires MFA for guest access"
    }
    It "MT.1017: At least one Conditional Access policy is configured to enforce non persistent browser session for non-corporate devices. See https://maester.dev/docs/tests/MT.1017" {
        Test-MtCaEnforceNonPersistentBrowserSession | Should -Be $true -Because "there is no policy that enforces non persistent browser session for non-corporate devices"
    }
    It "MT.1018: At least one Conditional Access policy is configured to enforce sign-in frequency for non-corporate devices. See https://maester.dev/docs/tests/MT.1018" {
        Test-MtCaEnforceSignInFrequency | Should -Be $true -Because "there is no policy that enforces sign-in frequency for non-corporate devices"
    }
    It "MT.1019: At least one Conditional Access policy is configured to enable application enforced restrictions. See https://maester.dev/docs/tests/MT.1019" {
        Test-MtCaApplicationEnforcedRestriction | Should -Be $true -Because "there is no policy that enables application enforced restrictions"
    }
    It "MT.1020: All Conditional Access policies are configured to exclude directory synchronization accounts or do not scope them. See https://maester.dev/docs/tests/MT.1020" {
        Test-MtCaExclusionForDirectorySyncAccount | Should -Be $true -Because "there is no policy that excludes directory synchronization accounts"
    }
    Context "License utilization" {
        It "MT.1022: All users covered by a P1 license are utilizing this license. See https://maester.dev/docs/tests/MT.1022" {
            $LicenseReport = Test-MtCaLicenseUtilization -License "P1"
            $LicenseReport.TotalLicensesUtilized | Should -BeGreaterOrEqual $LicenseReport.EntitledLicenseCount -Because "this is the maximium number of user that can utilize a P1 license"
        }
        It "MT.1023: All users covered by a P2 license are utilizing this license. See https://maester.dev/docs/tests/MT.1023" -Skip:( $EntraIDPlan -ne "P2" ) {
            $LicenseReport = Test-MtCaLicenseUtilization -License "P2"
            $LicenseReport.TotalLicensesUtilized | Should -BeGreaterOrEqual $LicenseReport.EntitledLicenseCount -Because "this is the maximium number of user that can utilize a P2 license"
        }
    }
}

Describe "Security Defaults" -Tag "CA", "Security", "All" -Skip:( $EntraIDPlan -ne "Free" ) {
    It "MT.1021: Security Defaults are enabled. See https://maester.dev/docs/tests/MT.1021" {
        $SecurityDefaults = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/policies/identitySecurityDefaultsEnforcementPolicy" | Select-Object -ExpandProperty isEnabled
        $SecurityDefaults | Should -Be $true -Because "Security Defaults are not enabled"
    }
}