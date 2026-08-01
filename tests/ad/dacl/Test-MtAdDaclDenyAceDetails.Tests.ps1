Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-06" {
    It "AD-DACL-06: Deny ACE details should be retrievable" {
        $result = Test-MtAdDaclDenyAceDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "deny ACE detail data should be accessible"
        }
    }
}
