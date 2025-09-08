Describe 'Maester/Entra' -Tag 'App', 'Entra', 'Full', 'Graph', 'LongRunning', 'Maester', 'Security' {
    It 'MT.1057: App registrations should no longer use secrets. See https://maester.dev/docs/tests/MT.1057' -Tag 'MT.1057' {
        Test-MtAppRegistrationsWithSecrets | Should -Be $true -Because 'app registrations should not use secrets and instead use workload identities or certificate-based authentication'
    }
    It 'MT.1058: Exchange application access policies must be configured. See https://maester.dev/docs/tests/MT.1058' -Tag 'MT.1058' {
        Test-MtSpExchangeAppAccessPolicy | Should -Be $true -Because 'all applications with Exchange permissions should have access policies configured'
    }
    It 'MT.1075: Require explicit assignment of Third Party Entra Apps. See https://maester.dev/docs/tests/MT.1075' -Tag 'MT.1075' {
        Test-MtServicePrincipalsForAllUsers | Should -Be $true -Because 'Third Party Service Principals should require explicit assignment to users'
    }
}
