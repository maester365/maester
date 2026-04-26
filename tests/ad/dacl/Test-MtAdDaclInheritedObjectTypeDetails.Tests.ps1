Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-18" {
    It "AD-DACL-18: Inherited object type details should be retrievable" {
        $result = Test-MtAdDaclInheritedObjectTypeDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "DACL data should be accessible"
        }
    }
}
