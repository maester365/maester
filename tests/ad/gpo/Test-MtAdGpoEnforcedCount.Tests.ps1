Describe "Active Directory - Group Policy" -Tag "AD", "AD.GPO", "AD-GPOL-04" {
    It "AD-GPOL-04: Enforced GPO link count should be retrievable" {
        $result = Test-MtAdGpoEnforcedCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Enforced GPO link data should be accessible"
        }
    }
}
