
Describe "App Management Policies" -Tag "App", "Security", "All" {
    It "ID1002: App management restrictions on applications and service principals is configured and enabled. See https://maester.dev/docs/tests/MT.1002" -Tag "L-WI" {
        Test-MtAppManagementPolicyEnabled | Should -Be $true -Because "an app policy for workload identities should be defined to enforce strong credentials instead of passwords and a maximum expiry period (e.g. credential should be renewed every sixe months)"
    }
}
