
Describe "Conditional Access Baseline Policies" -Tag "CA", "Security", "All" {
    It "ID1001: At least one Conditional Access policy is configured with device compliance" {
        Test-MtCaDeviceComplianceExists | Should -Be $true
    }
    It "ID1003: At least one Conditional Access policy is configured with All Apps" {
        Test-MtCaAllAppsExists -SkipCheckAllUsers | Should -Be $true
    }
    It "ID1004: At least one Conditional Access policy is configured with All Apps and All Users" {
        Test-MtCaAllAppsExists | Should -Be $true
    }
    It "ID1006: At least one Conditional Access policy is configured to require MFA for admins" {
        Test-MtCaAllAppsExists | Should -Be $true -Because "There is no policy that requires MFA for admins"
    }
    It "ID1007: At least one Conditional Access policy is configured to require MFA for all users" {
        Test-MtCaMfaForAllUsers | Should -Be $true -Because "There is no policy that requires MFA for all users"
    }
}
