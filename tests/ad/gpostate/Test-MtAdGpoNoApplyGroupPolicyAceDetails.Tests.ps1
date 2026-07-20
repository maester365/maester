Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-11" {
    It "AD-GPOREP-11: GPO no-apply Group Policy ACE details should be retrievable" {
        $result = Test-MtAdGpoNoApplyGroupPolicyAceDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO report data should be accessible"
        }
    }
}
