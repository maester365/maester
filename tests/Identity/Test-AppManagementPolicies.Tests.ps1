
BeforeDiscovery {
}

BeforeAll {

}

Describe "App Management Policies" -Tag "App", "Security", "All" {
    It "App management restrictions on applications and service principals is configured and enabled" {
        Test-MtAppManagementPolicyEnabled | Should -Be $true
    }
}
