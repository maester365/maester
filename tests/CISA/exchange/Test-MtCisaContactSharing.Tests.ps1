BeforeDiscovery {
    $exoSession = Test-MtConnection -Service ExchangeOnline
}

Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.6.1", "CISA", "Security", "All" -Skip:((-not $exoSession)) {
    It "MS.EXO.6.1: Contact folders SHALL NOT be shared with all domains." {
        Test-MtCisaContactSharing | Should -Be $true -Because "contact sharing is disabled."
    }
}