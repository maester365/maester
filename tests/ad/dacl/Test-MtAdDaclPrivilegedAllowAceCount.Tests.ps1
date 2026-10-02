Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-09" {
    It "AD-DACL-09: Privileged allow ACE count should be investigated" {
        $result = Test-MtAdDaclPrivilegedAllowAceCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "privileged allow ACE data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
