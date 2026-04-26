Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-10" {
    It "AD-DACL-10: Privileged allow ACE details should be retrievable" {
        $result = Test-MtAdDaclPrivilegedAllowAceDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "privileged allow ACE details should be accessible"
        }
    }
}
