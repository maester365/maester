
Describe "Conditional Access Baseline Policies" -Tag "CA", "Security", "All" {
    It "MT1001: At least one Conditional Access policy is configured with device compliance. See https://maester.dev/docs/tests/MT.1001" {
        Test-MtCaDeviceComplianceExists | Should -Be $true -Because "there is no policy which requires device compliances"
    }
    It "MT1003: At least one Conditional Access policy is configured with All Apps. See https://maester.dev/docs/tests/MT.1003" {
        Test-MtCaAllAppsExists -SkipCheckAllUsers | Should -Be $true -Because "there is no policy scoped to All Apps"
    }
    It "MT1004: At least one Conditional Access policy is configured with All Apps and All Users. See https://maester.dev/docs/tests/MT.1004" {
        Test-MtCaAllAppsExists | Should -Be $true -Because "there is no policy scoped to All Apps and All Users"
    }
    It "MT1005: All Conditional Access policies are configured to exclude at least one emergency/break glass account or group. See https://maester.dev/docs/tests/MT.1005" {
        Test-MtCaEmergencyAccessExists | Should -Be $true -Because "there is no emergency access account or group present in all enabled policies"
    }
    It "MT1006: At least one Conditional Access policy is configured to require MFA for admins. See https://maester.dev/docs/tests/MT.1006" {
        Test-MtCaAllAppsExists | Should -Be $true -Because "there is no policy that requires MFA for admins"
    }
    It "MT1007: At least one Conditional Access policy is configured to require MFA for all users. See https://maester.dev/docs/tests/MT.1007" {
        Test-MtCaMfaForAllUsers | Should -Be $true -Because "there is no policy that requires MFA for all users"
    }
    It "MT1008: At least one Conditional Access policy is configured to require MFA for Azure management. See https://maester.dev/docs/tests/MT.1008" {
        Test-MtCaMfaForAdminManagement | Should -Be $true -Because "there is no policy that requires MFA for Azure management"
    }
    It "MT1009: At least one Conditional Access policy is configured to block other legacy authentication. See https://maester.dev/docs/tests/MT.1009" {
        Test-MtCaBlockLegacyOtherAuthentication | Should -Be $true -Because "there is no policy that blocks legacy authentication"
    }
    It "MT1010: At least one Conditional Access policy is configured to block legacy authentication for Exchange ActiveSync. See https://maester.dev/docs/tests/MT.1010" {
        Test-MtCaBlockLegacyExchangeActiveSyncAuthentication | Should -Be $true -Because "there is no policy that blocks legacy authentication for Exchange ActiveSync"
    }
    It "MT1011: At least one Conditional Access policy is configured to secure security info registration only from a trusted location. See https://maester.dev/docs/tests/MT.1011" {
        Test-MtCaSecureSecurityInfoRegistration | Should -Be $true -Because "there is no policy that secures security info registration"
    }
    It "MT1012: At least one Conditional Access policy is configured to require MFA for risky sign-ins. See https://maester.dev/docs/tests/MT.1012" {
        Test-MtCaMfaForRiskySignIns | Should -Be $true -Because "there is no policy that requires MFA for risky sign-ins"
    }
    It "MT1013: At least one Conditional Access policy is configured to require new password when user risk is high. See https://maester.dev/docs/tests/MT.1013" {
        Test-MtCaRequirePasswordChangeForHighUserRisk | Should -Be $true -Because "there is no policy that requires new password when user risk is high"
    }
    It "MT1014: At least one Conditional Access policy is configured to require compliant or hybrid Azure AD joined devices for admins. See https://maester.dev/docs/tests/MT.1014" {
        Test-MtCaDeviceComplianceAdminsExists | Should -Be $true -Because "there is no policy that requires compliant or hybrid Azure AD joined devices for admins"
    }
    It "MT1015: At least one Conditional Access policy is configured to block access for unknown or unsupported device platforms. See https://maester.dev/docs/tests/MT.1015" {
        Test-MtCaBlockUnknownOrUnsupportedDevicePlatforms | Should -Be $true -Because "there is no policy that blocks access for unknown or unsupported device platforms"
    }
    It "MT1016: At least one Conditional Access policy is configured to require MFA for guest access. See https://maester.dev/docs/tests/MT.1016" {
        Test-MtCaMfaForGuests | Should -Be $true -Because "there is no policy that requires MFA for guest access"
    }
    It "MT1017: At least one Conditional Access policy is configured to enforce non persistent browser session for non-corporate devices. See https://maester.dev/docs/tests/MT.1017" {
        Test-MtCaEnforceNonPersistentBrowserSession | Should -Be $true -Because "there is no policy that enforces non persistent browser session for non-corporate devices"
    }
    It "MT1018: At least one Conditional Access policy is configured to enforce sign-in frequency for non-corporate devices. See https://maester.dev/docs/tests/MT.1018" {
        Test-MtCaEnforceSignInFrequency | Should -Be $true -Because "there is no policy that enforces sign-in frequency for non-corporate devices"
    }
    It "MT1019: At least one Conditional Access policy is configured to enable application enforced restrictions. See https://maester.dev/docs/tests/MT.1019" {
        Test-MtCaApplicationEnforcedRestrictions | Should -Be $true -Because "there is no policy that enables application enforced restrictions"
    }
    It "MT1020: All Conditional Access policies are configured to exclude directory synchronization accounts or do not scope them. See https://maester.dev/docs/tests/MT.1020" {
        Test-MtCaExclusionForDirectorySyncAccounts | Should -Be $true -Because "there is no policy that excludes directory synchronization accounts"
    }
}
