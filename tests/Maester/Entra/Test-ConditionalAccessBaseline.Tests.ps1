Describe "Conditional Access Baseline Policies" -Tag "Maester", "CA", "Security", "All" {
    It "MT.1001: At least one Conditional Access policy is configured with device compliance. See https://maester.dev/docs/tests/MT.1001" -Tag "MT.1001" {
        Test-MtCaDeviceComplianceExists | Should -Be $true -Because "there is no policy which requires device compliances"
    }
    It "MT.1003: At least one Conditional Access policy is configured with All Apps. See https://maester.dev/docs/tests/MT.1003" -Tag "MT.1003" {
        Test-MtCaAllAppsExists -SkipCheckAllUsers | Should -Be $true -Because "there is no policy scoped to All Apps"
    }
    It "MT.1004: At least one Conditional Access policy is configured with All Apps and All Users. See https://maester.dev/docs/tests/MT.1004" -Tag "MT.1004" {
        Test-MtCaAllAppsExists | Should -Be $true -Because "there is no policy scoped to All Apps and All Users"
    }
    It "MT.1005: All Conditional Access policies are configured to exclude at least one emergency/break glass account or group. See https://maester.dev/docs/tests/MT.1005" -Tag "MT.1005" {
        Test-MtCaEmergencyAccessExists | Should -Be $true -Because "there is no emergency access account or group present in all enabled policies"
    }
    It "MT.1006: At least one Conditional Access policy is configured to require MFA for admins. See https://maester.dev/docs/tests/MT.1006" -Tag "MT.1006" {
        Test-MtCaMfaForAdmin | Should -Be $true -Because "there is no policy that requires MFA for admins"
    }
    It "MT.1007: At least one Conditional Access policy is configured to require MFA for all users. See https://maester.dev/docs/tests/MT.1007" -Tag "MT.1007" {
        Test-MtCaMfaForAllUsers | Should -Be $true -Because "there is no policy that requires MFA for all users"
    }
    It "MT.1008: At least one Conditional Access policy is configured to require MFA for Azure management. See https://maester.dev/docs/tests/MT.1008" -Tag "MT.1008" {
        Test-MtCaMfaForAdminManagement | Should -Be $true -Because "there is no policy that requires MFA for Azure management"
    }
    It "MT.1009: At least one Conditional Access policy is configured to block other legacy authentication. See https://maester.dev/docs/tests/MT.1009" -Tag "MT.1009" {
        Test-MtCaBlockLegacyOtherAuthentication | Should -Be $true -Because "there is no policy that blocks legacy authentication"
    }
    It "MT.1010: At least one Conditional Access policy is configured to block legacy authentication for Exchange ActiveSync. See https://maester.dev/docs/tests/MT.1010" -Tag "MT.1010" {
        Test-MtCaBlockLegacyExchangeActiveSyncAuthentication | Should -Be $true -Because "there is no policy that blocks legacy authentication for Exchange ActiveSync"
    }
    It "MT.1011: At least one Conditional Access policy is configured to secure security info registration only from a trusted location. See https://maester.dev/docs/tests/MT.1011" -Tag "MT.1011" {
        Test-MtCaSecureSecurityInfoRegistration | Should -Be $true -Because "there is no policy that secures security info registration"
    }
    It "MT.1012: At least one Conditional Access policy is configured to require MFA for risky sign-ins. See https://maester.dev/docs/tests/MT.1012" -Skip:( $EntraIDPlan -eq "P1" ) -Tag "MT.1012" {
        Test-MtCaMfaForRiskySignIn | Should -Be $true -Because "there is no policy that requires MFA for risky sign-ins"
    }
    It "MT.1013: At least one Conditional Access policy is configured to require new password when user risk is high. See https://maester.dev/docs/tests/MT.1013" -Skip:( $EntraIDPlan -eq "P1" ) -Tag "MT.1013" {
        Test-MtCaRequirePasswordChangeForHighUserRisk | Should -Be $true -Because "there is no policy that requires new password when user risk is high"
    }
    It "MT.1014: At least one Conditional Access policy is configured to require compliant or Entra hybrid joined devices for admins. See https://maester.dev/docs/tests/MT.1014" -Tag "MT.1014" {
        Test-MtCaDeviceComplianceAdminsExists | Should -Be $true -Because "there is no policy that requires compliant or Entra hybrid joined devices for admins"
    }
    It "MT.1015: At least one Conditional Access policy is configured to block access for unknown or unsupported device platforms. See https://maester.dev/docs/tests/MT.1015" -Tag "MT.1015" {
        Test-MtCaBlockUnknownOrUnsupportedDevicePlatform | Should -Be $true -Because "there is no policy that blocks access for unknown or unsupported device platforms"
    }
    It "MT.1016: At least one Conditional Access policy is configured to require MFA for guest access. See https://maester.dev/docs/tests/MT.1016" -Tag "MT.1016" {
        Test-MtCaMfaForGuest | Should -Be $true -Because "there is no policy that requires MFA for guest access"
    }
    It "MT.1017: At least one Conditional Access policy is configured to enforce non persistent browser session for non-corporate devices. See https://maester.dev/docs/tests/MT.1017" -Tag "MT.1017" {
        Test-MtCaEnforceNonPersistentBrowserSession | Should -Be $true -Because "there is no policy that enforces non persistent browser session for non-corporate devices"
    }
    It "MT.1018: At least one Conditional Access policy is configured to enforce sign-in frequency for non-corporate devices. See https://maester.dev/docs/tests/MT.1018" -Tag "MT.1018" {
        Test-MtCaEnforceSignInFrequency | Should -Be $true -Because "there is no policy that enforces sign-in frequency for non-corporate devices"
    }
    It "MT.1019: At least one Conditional Access policy is configured to enable application enforced restrictions. See https://maester.dev/docs/tests/MT.1019" -Tag "MT.1019" {
        Test-MtCaApplicationEnforcedRestriction | Should -Be $true -Because "there is no policy that enables application enforced restrictions"
    }
    It "MT.1020: All Conditional Access policies are configured to exclude directory synchronization accounts or do not scope them. See https://maester.dev/docs/tests/MT.1020" -Tag "MT.1020" {
        Test-MtCaExclusionForDirectorySyncAccount | Should -Be $true -Because "there is no policy that excludes directory synchronization accounts"
    }
    It "MT.1035: All security groups assigned to Conditional Access Policies should be protected by RMAU. See https://maester.dev/docs/tests/MT.1035" -Tag "MT.1035" {
        Test-MtCaGroupsRestricted | Should -Be $true -Because "there is one or more policy without protection of included or excluded groups"
    }
    It "MT.1036: All excluded objects should have a fallback include in another policy. See https://maester.dev/docs/tests/MT.1036" -Tag "MT.1036", "Warning" {
        Test-MtCaGap | Should -Be $true -Because "there is one ore more object excluded without an include fallback in another policy."
    }
    Context "License utilization" {
        It "MT.1022: All users utilizing a P1 license should be licensed. See https://maester.dev/docs/tests/MT.1022" -Tag "MT.1022" {
            $LicenseReport = Test-MtCaLicenseUtilization -License "P1"
            $LicenseReport.TotalLicensesUtilized | Should -BeLessOrEqual $LicenseReport.EntitledLicenseCount -Because "this is the maximium number of user that can utilize a P1 license"
        }
        It "MT.1023: All users utilizing a P2 license should be licensed. See https://maester.dev/docs/tests/MT.1023" -Tag "MT.1023" {
            $LicenseReport = Test-MtCaLicenseUtilization -License "P2"
            $LicenseReport.TotalLicensesUtilized | Should -BeLessOrEqual $LicenseReport.EntitledLicenseCount -Because "this is the maximium number of user that can utilize a P2 license"
        }
    }
}

Describe "Security Defaults" -Tag "CA", "Security", "All" {
    It "MT.1021: Security Defaults are enabled. See https://maester.dev/docs/tests/MT.1021" -Tag "MT.1021" {
        $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
        if ($EntraIDPlan -ne "Free") {
            Add-MtTestResultDetail -SkippedBecause LicensedEntraIDPremium
        } else {
            $SecurityDefaults = Invoke-MtGraphRequest -RelativeUri "policies/identitySecurityDefaultsEnforcementPolicy" -ApiVersion beta | Select-Object -ExpandProperty isEnabled
            $SecurityDefaults | Should -Be $true -Because "Security Defaults are not enabled"
        }
    }
}
