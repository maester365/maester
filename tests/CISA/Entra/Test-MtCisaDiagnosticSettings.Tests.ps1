BeforeAll {
    $azureSession = $__MtSession.Connections -contains "Azure" -or $__MtSession.Connections -contains "All"
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.4.1", "CISA", "Security", "All" -Skip:((-not $azureSession)) {
    It "MS.AAD.4.1: Security logs SHALL be sent to the agency's security operations center for monitoring." {
        Test-MtCisaDiagnosticSettings | Should -Be $true -Because "diagnostic settings are configured for all logs."
    }
}