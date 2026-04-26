Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD.GMC", "AD-GMC-11" {
    It "AD-GMC-11: Privileged groups with members details should be retrievable" {

        $result = Test-MtAdGroupPrivilegedWithMembersDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "privileged group member details should be accessible"
        }
    }
}
