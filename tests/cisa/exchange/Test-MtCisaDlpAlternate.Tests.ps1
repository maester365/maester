Describe "CISA" -Tag "MS.EXO", "MS.EXO.8.3", "CISA.MS.EXO.8.3", "CISA", "Security" {
    It "CISA.MS.EXO.8.3: The selected DLP solution SHOULD offer services comparable to the native DLP solution offered by Microsoft." {

        $cisa = Test-MtCisaDlpAlternate

        if ($null -ne $cisa) {
            $cisa | Should -Be $true -Because "will not reach here."
        }
    }
}
