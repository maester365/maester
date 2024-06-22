BeforeDiscovery {
    $exoSession = Test-MtConnection -Service ExchangeOnline
}

Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.12.1", "CISA", "Security", "All" -Skip:((-not $exoSession)) {
    It "MS.EXO.12.1: IP allow lists SHOULD NOT be created." {
        Test-MtCisaAntiSpamAllowList | Should -Be $true -Because "no anti-spam policy allow IPs."
    }
}