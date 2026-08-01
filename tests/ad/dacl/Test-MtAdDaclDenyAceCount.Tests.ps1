Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-05" {
    It "AD-DACL-05: Deny ACE count should be retrievable" {
        $result = Test-MtAdDaclDenyAceCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "deny ACE count data should be accessible"
        }
    }
}
