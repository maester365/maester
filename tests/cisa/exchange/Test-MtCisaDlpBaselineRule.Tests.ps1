Describe "CISA" -Tag "MS.EXO", "MS.EXO.8.4", "CISA.MS.EXO.8.4", "CISA", "Security" {
    It "CISA.MS.EXO.8.4: At a minimum, the DLP solution SHALL restrict sharing credit card numbers, U.S. Individual Taxpayer Identification Numbers (ITIN), and U.S. Social Security numbers (SSN) via email." {

        $cisa = Test-MtCisaDlpBaselineRule

        if ($null -ne $cisa) {
            $cisa | Should -Be $true -Because "baseline DLP rules are in use."
        }
    }
}
