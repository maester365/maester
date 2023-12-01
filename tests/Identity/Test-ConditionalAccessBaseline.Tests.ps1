
BeforeDiscovery {
}

BeforeAll {

}

Describe "Conditional Access Baseline Policies" -Tag "CA", "Security", "All" {
    It "ID1001: At least one Conditional Access policy is configured with device compliance" {
        Test-MtCaHasDeviceCompliance | Should -Be $true
    }
}
