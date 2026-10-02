Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-06" {
    It "AD-DACL-06: Deny ACE details should be investigated" {
        $result = Test-MtAdDaclDenyAceDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "deny ACE detail data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
