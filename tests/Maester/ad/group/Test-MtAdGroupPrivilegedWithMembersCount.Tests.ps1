Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD.GMC", "AD-GMC-10" {
    It "AD-GMC-10: Privileged groups with members count should be retrievable" {

        $result = Test-MtAdGroupPrivilegedWithMembersCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "privileged group membership data should be accessible"
        }
    }
}
