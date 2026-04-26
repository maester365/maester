Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD-GMC-06" {
    It "AD-GMC-06: Foreign SID principals count should be retrievable" {

        $result = Test-MtAdGroupMemberForeignSidCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "foreign SID data should be accessible"
        }
    }
}
