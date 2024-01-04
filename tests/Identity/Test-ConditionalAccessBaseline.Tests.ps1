
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

}
