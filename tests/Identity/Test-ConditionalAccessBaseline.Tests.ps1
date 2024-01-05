
Describe "Conditional Access Baseline Policies" -Tag "CA", "Security", "All" {
    It "ID1001: At least one Conditional Access policy is configured with device compliance" {
        Test-MtCaDeviceComplianceExists | Should -Be $true -Because "There is no policy which requires device compliances"
    }
    It "ID1003: At least one Conditional Access policy is configured with All Apps" {
        Test-MtCaAllAppsExists -SkipCheckAllUsers | Should -Be $true -Because "There is no policy scoped to All Apps"
    }
    It "ID1004: At least one Conditional Access policy is configured with All Apps and All Users" {
        Test-MtCaAllAppsExists | Should -Be $true -Because "There is no policy scoped to All Apps and All Users"
    }
    It "ID1005: All Conditional Access policies are configured to exclude at least one emergency account or group" {
        Test-MtCaEmergencyAccessExists | Should -Be $true -Because "There is no emergency access account or group present in all enabled policies"
    }
    It "ID1006: At least one Conditional Access policy is configured to require MFA for admins" {
        Test-MtCaAllAppsExists | Should -Be $true -Because "There is no policy that requires MFA for admins"
    }
    It "ID1007: At least one Conditional Access policy is configured to require MFA for all users" {
        Test-MtCaMfaForAllUsers | Should -Be $true -Because "There is no policy that requires MFA for all users"
    }
}
