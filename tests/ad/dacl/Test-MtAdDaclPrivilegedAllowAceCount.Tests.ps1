Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-09" {
    It "AD-DACL-09: Privileged allow ACE count should be retrievable" {
        $result = Test-MtAdDaclPrivilegedAllowAceCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "privileged allow ACE data should be accessible"
        }
    }
}
