Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-14" {
    It "AD-DACL-14: Non-inherited ACE count should be investigated" {
        $result = Test-MtAdDaclNonInheritedAceCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "DACL data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
