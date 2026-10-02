Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-15" {
    It "AD-DACL-15: Unresolved SID count should be investigated" {
        $result = Test-MtAdDaclUnresolvedSidCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "DACL data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
