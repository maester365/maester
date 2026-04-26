Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-07" {
    It "AD-DACL-07: Distinct DACL identity count should be retrievable" {
        $result = Test-MtAdDaclDistinctIdentityCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DACL identity count data should be accessible"
        }
    }
}
