Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-10" {
    It "AD-GPOREP-10: GPO no-apply Group Policy ACE count should be retrievable" {
        $result = Test-MtAdGpoNoApplyGroupPolicyAceCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO report data should be accessible"
        }
    }
}
