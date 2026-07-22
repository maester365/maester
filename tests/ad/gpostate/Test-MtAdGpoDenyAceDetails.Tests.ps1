Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-08" {
    It "AD-GPOREP-08: GPOs with deny ACE details should be retrievable" {
        $result = Test-MtAdGpoDenyAceDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO permissions data should be accessible"
        }
    }
}
