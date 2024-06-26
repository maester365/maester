BeforeDiscovery {
    $exoSession = Test-MtConnection -Service ExchangeOnline
}

Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.5.1", "CISA", "Security", "All" -Skip:((-not $exoSession)) {
    It "MS.EXO.5.1: SMTP AUTH SHALL be disabled." {
        Test-MtCisaSmtpAuthentication | Should -Be $true -Because "SMTP Authentication is disabled."
    }
}