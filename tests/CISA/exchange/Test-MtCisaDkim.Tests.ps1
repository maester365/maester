Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.3.1", "CISA", "Security", "All" {
    It "MS.EXO.3.1: DKIM SHOULD be enabled for all domains." {
        $cisaDkim = Test-MtCisaDkim

        if ($null -ne $cisaDkim) {
            $cisaDkim | Should -Be $true -Because "DKIM record should exist and be configured."
        }
    }
}