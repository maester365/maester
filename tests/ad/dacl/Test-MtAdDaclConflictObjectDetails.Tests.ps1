Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-04" {
    It "AD-DACL-04: Conflict object details should be retrievable" {
        $result = Test-MtAdDaclConflictObjectDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "conflict object detail data should be accessible"
        }
    }
}
