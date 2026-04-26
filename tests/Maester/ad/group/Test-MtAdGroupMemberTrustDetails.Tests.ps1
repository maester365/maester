Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD-GMC-05" {
    It "AD-GMC-05: Trust members details by group should be retrievable" {

        $result = Test-MtAdGroupMemberTrustDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "trust member details should be accessible"
        }
    }
}
