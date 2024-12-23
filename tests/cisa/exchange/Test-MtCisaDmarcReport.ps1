Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.4.4", "CISA", "Security", "All" {
    It "MS.EXO.04.4: An agency point of contact SHOULD be included for aggregate and failure reports." {
        $cisaDmarcReport = Test-MtCisaDmarcReport

        if ($null -ne $cisaDmarcReport) {
            $cisaDmarcReport | Should -Be $true -Because "DMARC report targets should exist."
        }
    }
}