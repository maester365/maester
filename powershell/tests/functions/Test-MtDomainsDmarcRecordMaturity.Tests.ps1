Describe 'Test-MtDomainsDmarcRecordMaturity' {
    BeforeEach {
        $script:skipCustomReason = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param(
                $SkippedBecause,
                $SkippedCustomReason
            )

            $script:skipCustomReason = $SkippedCustomReason
        }
    }

    It 'skips cleanly when no verified managed domains are found' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtDomainsDmarcRecordMaturity | Should -Be $null
        $script:skipCustomReason | Should -Be 'No verified and managed domains found in tenant'
    }
}
