BeforeDiscovery {
    $exoSession = Test-MtConnection -Service ExchangeOnline
}

Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.6.2", "CISA", "Security", "All" -Skip:((-not $exoSession)) {
    It "MS.EXO.6.2: Calendar details SHALL NOT be shared with all domains." {
        Test-MtCisaCalendarSharing | Should -Be $true -Because "calendar sharing is disabled."
    }
}