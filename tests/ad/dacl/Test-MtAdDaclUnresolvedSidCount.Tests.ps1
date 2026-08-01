Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-15" {
    It "AD-DACL-15: Unresolved SID count should be retrievable" {
        $result = Test-MtAdDaclUnresolvedSidCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "DACL data should be accessible"
        }
    }
}
