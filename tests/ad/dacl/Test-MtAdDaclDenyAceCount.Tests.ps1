Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-05" {
    It "AD-DACL-05: Deny ACE count should be investigated" {
        $result = Test-MtAdDaclDenyAceCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "deny ACE count data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
