Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.4.3", "CISA", "Security", "All" {
    It "MS.EXO.4.3: The DMARC point of contact for aggregate reports SHALL include reports@dmarc.cyber.dhs.gov." {
        $cisaDmarcAggregateCisa = Test-MtCisaDmarcAggregateCisa

        if ($null -ne $cisaDmarcAggregateCisa) {
            $cisaDmarcAggregateCisa | Should -Be $true -Because "DMARC record includes proper aggregate target."
        }
    }
}