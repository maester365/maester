BeforeAll {
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name @(
        'Test-MtCisaDlpAlternate',
        'Test-MtCheckCISAMSEXO92',
        'Test-MtCisaEmailFilterAlternative',
        'Test-MtCisaMailboxIntelligence'
    )
}

Describe 'Deprecated CISA Exchange checks' {
    BeforeEach {
        $script:SkippedBecause = $null
        $script:SkippedCustomReason = $null

        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($SkippedBecause, $SkippedCustomReason)

            $script:SkippedBecause = $SkippedBecause
            $script:SkippedCustomReason = $SkippedCustomReason
        }
    }

    It '<CheckName> skips the retired control' -ForEach @(
        @{ CheckName = 'Test-MtCisaDlpAlternate' }
        @{ CheckName = 'Test-MtCheckCISAMSEXO92' }
        @{ CheckName = 'Test-MtCisaEmailFilterAlternative' }
        @{ CheckName = 'Test-MtCisaMailboxIntelligence' }
    ) {
        & $CheckName | Should -BeNull
        $script:SkippedBecause | Should -Be 'Custom'
        $script:SkippedCustomReason | Should -Match 'removed'
    }
}
