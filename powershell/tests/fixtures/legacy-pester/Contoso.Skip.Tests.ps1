# Legacy Pester fixture: -Skip with a literal and with an expression.
BeforeDiscovery {
    $featureEnabled = $false
}

Describe "Contoso optional features" -Tag "Contoso" {
    It "CONTOSO.3101: Always skipped" -Tag "CONTOSO.3101" -Skip {
        $true | Should -BeTrue
    }

    It "CONTOSO.3102: Skipped when the feature is disabled" -Tag "CONTOSO.3102" -Skip:(-not $featureEnabled) {
        $true | Should -BeTrue
    }

    It "CONTOSO.3103: Runs because the skip expression is false" -Tag "CONTOSO.3103" -Skip:($PSVersionTable.PSVersion.Major -lt 5) {
        $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 5
    }
}
