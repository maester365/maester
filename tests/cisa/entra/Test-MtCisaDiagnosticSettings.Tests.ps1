Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.4.1", "CISA", "Security", "All", "Entra ID P1" {
    It "MS.AAD.4.1: Security logs SHALL be sent to the agency's security operations center for monitoring." {
        $cisaDiagnosticSettings = Test-MtCisaDiagnosticSettings

        if ($null -ne $cisaDiagnosticSettings) {
            $cisaDiagnosticSettings | Should -Be $true -Because "diagnostic settings are configured for all logs."
        }
    }
}