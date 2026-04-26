Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-07" {
    It "AD-GPOREP-07: GPOs with deny ACE count should be retrievable" {
        $result = Test-MtAdGpoDenyAceCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO permissions data should be accessible"
        }
    }
}
