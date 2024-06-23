BeforeDiscovery {
    $exoSession = Test-MtConnection -Service ExchangeOnline
}

Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.1.1", "CISA", "Security", "All" -Skip:((-not $exoSession)) {
    It "MS.EXO.1.1: Automatic forwarding to external domains SHALL be disabled." {
        Test-MtCisaAutoExternalForwarding | Should -Be $true -Because "auto forwarding is not enabled for any domains"
    }
}