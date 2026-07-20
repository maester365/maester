Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD-GMC-04" {
    It "AD-GMC-04: Trust members count should be retrievable" {

        $result = Test-MtAdGroupMemberTrustCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "trust member data should be accessible"
        }
    }
}
