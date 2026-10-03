Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-17" {
    It "AD-DACL-17: Inherited object type count should be investigated" {
        $result = Test-MtAdDaclInheritedObjectTypeCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "DACL data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
