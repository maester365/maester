Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-01" {
    It "AD-DACL-01: Distinct DACL object count should be investigated" {
        $result = Test-MtAdDaclDistinctObjectCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "DACL object count data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
