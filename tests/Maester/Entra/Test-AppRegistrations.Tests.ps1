Describe 'Maester/Entra' -Tag 'App', 'Entra', 'Graph', 'LongRunning', 'Maester' {
    It 'MT.1057: App registrations should no longer use secrets. See https://maester.dev/docs/tests/MT.1057' -Tag 'MT.1057' {
        Test-MtAppRegistrationsWithSecrets | Should -Be $true -Because 'app registrations should not use secrets and instead use workload identities or certificate-based authentication'
    }
    It 'MT.1058: Exchange application access policies must be configured. See https://maester.dev/docs/tests/MT.1058' -Tag 'MT.1058' {
        $result = Test-MtSpExchangeAppAccessPolicy

        if ($null -ne $result) {
            $result | Should -Be $true -Because 'all applications with Exchange permissions should have access policies configured'
        }
    }
    It 'MT.1075: Require explicit assignment of Third Party Entra Apps. See https://maester.dev/docs/tests/MT.1075' -Tag 'MT.1075' {
        Test-MtServicePrincipalsForAllUsers | Should -Be $true -Because 'Third Party Service Principals should require explicit assignment to users'
    }
    It 'MT.1198: App registration certificates should not have excessive validity periods. See https://maester.dev/docs/tests/MT.1198' -Tag 'MT.1198' {
        $result = Test-MtAppRegistrationCertificateLifetime

        if ($null -ne $result) {
            $result | Should -Be $true -Because 'a certificate with a long validity period stays usable for years if the private key is stolen'
        }
    }
}
