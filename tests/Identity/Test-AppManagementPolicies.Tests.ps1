
Describe "App Management Policies" -Tag "App", "Security", "All" {
    It "ID1002: App management restrictions on applications and service principals is configured and enabled. See https://maester.dev/t/ID1002" {
        Test-MtAppManagementPolicyEnabled | Should -Be $true -Because "There is no app policy to use secure credentials"
    }
}
