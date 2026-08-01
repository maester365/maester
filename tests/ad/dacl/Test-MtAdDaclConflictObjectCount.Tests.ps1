Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-03" {
    It "AD-DACL-03: Conflict object count should be retrievable" {
        $result = Test-MtAdDaclConflictObjectCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "conflict object DACL data should be accessible"
        }
    }
}
