Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-10" {
    It "AD-DACL-10: Privileged allow ACE details should be investigated" {
        $result = Test-MtAdDaclPrivilegedAllowAceDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "privileged allow ACE details should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
