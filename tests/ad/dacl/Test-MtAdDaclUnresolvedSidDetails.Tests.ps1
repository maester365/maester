Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-16" {
    It "AD-DACL-16: Unresolved SID details should be investigated" {
        $result = Test-MtAdDaclUnresolvedSidDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "DACL data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
