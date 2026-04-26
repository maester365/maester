Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD-GMC-01" {
    It "AD-GMC-01: Distinct groups with members count should be retrievable" {

        $result = Test-MtAdGroupMemberDistinctGroupCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "group member data should be accessible"
        }
    }
}
