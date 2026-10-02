Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-18" {
    It "AD-DACL-18: Inherited object type details should be investigated" {
        $result = Test-MtAdDaclInheritedObjectTypeDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "DACL data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
