Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD.GMC", "AD-GMC-07" {
    It "AD-GMC-07: Foreign SID details by domain should be retrievable" {

        $result = Test-MtAdGroupMemberForeignSidDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "foreign SID data should be accessible"
        }
    }
}
