BeforeDiscovery {
    $exoSession = Test-MtConnection -Service ExchangeOnline
}

Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.12.2", "CISA", "Security", "All" -Skip:((-not $exoSession)) {
    It "MS.EXO.12.2: Safe lists SHOULD NOT be enabled." {
        Test-MtCisaAntiSpamSafeList | Should -Be $true -Because "Safe Lists should be disabled."
    }
}