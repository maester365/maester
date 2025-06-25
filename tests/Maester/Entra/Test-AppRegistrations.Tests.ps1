Describe "Maester/Entra" -Tag "Maester", "App", "Security", "Full", "Entra", "Graph" {
    It "MT.1057: App registrations should no longer use secrets. See https://maester.dev/docs/tests/MT.1057" -Tag "MT.1057" {
        Test-MtAppRegistrationsWithSecrets | Should -Be $true -Because "app registrations should not use secrets and instead use workload identities or certificate-based authentication"
    }
    It "MT.1058: Exchange application access policies must be configured. See https://maester.dev/docs/tests/MT.1058" -Tag "MT.1058" {
        Test-MtSpExchangeAppAccessPolicy | Should -Be $true -Because "all applications with Exchange permissions should have access policies configured"
    }
}