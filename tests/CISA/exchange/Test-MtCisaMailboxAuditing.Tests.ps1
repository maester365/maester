BeforeDiscovery {
    $exoSession = Test-MtConnection -Service ExchangeOnline
}

Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.13.1", "CISA", "Security", "All" -Skip:((-not $exoSession)) {
    It "MS.EXO.13.1: Mailbox auditing SHALL be enabled." {
        Test-MtCisaMailboxAuditing | Should -Be $true -Because "mailbox auditing is enabled."
    }
}