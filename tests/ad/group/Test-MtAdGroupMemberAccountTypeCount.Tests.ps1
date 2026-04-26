Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD-GMC-02" {
    It "AD-GMC-02: Distinct account types of members count should be retrievable" {

        $result = Test-MtAdGroupMemberAccountTypeCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "account type data should be accessible"
        }
    }
}
