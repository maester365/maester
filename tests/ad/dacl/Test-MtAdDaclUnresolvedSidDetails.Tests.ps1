Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-16" {
    It "AD-DACL-16: Unresolved SID details should be retrievable" {
        $result = Test-MtAdDaclUnresolvedSidDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "DACL data should be accessible"
        }
    }
}
