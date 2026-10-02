Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-02" {
    It "AD-DACL-02: OU DACL entry count should be investigated" {
        $result = Test-MtAdDaclOuObjectCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "OU DACL data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
