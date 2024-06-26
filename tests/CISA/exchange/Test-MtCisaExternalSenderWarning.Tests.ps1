BeforeDiscovery {
    $exoSession = Test-MtConnection -Service ExchangeOnline
}

Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.7.1", "CISA", "Security", "All" -Skip:((-not $exoSession)) {
    It "MS.EXO.7.1: External sender warnings SHALL be implemented." {
        Test-MtCisaExternalSenderWarning | Should -Be $true -Because "external sender warning is set."
    }
}