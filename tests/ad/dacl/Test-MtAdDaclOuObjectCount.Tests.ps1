Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-02" {
    It "AD-DACL-02: OU DACL entry count should be retrievable" {
        $result = Test-MtAdDaclOuObjectCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "OU DACL data should be accessible"
        }
    }
}
