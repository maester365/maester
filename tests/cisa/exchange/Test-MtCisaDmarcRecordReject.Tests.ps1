Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.4.2", "CISA", "Security", "All" {
    It "MS.EXO.4.2: The DMARC message rejection option SHALL be p=reject." {
        $cisaDmarcRecordReject = Test-MtCisaDmarcRecordReject

        if ($null -ne $cisaDmarcRecordReject) {
            $cisaDmarcRecordReject | Should -Be $true -Because "DMARC record policy should be reject."
        }
    }
}