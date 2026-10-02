Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD-GMC-05" {
    It "AD-GMC-05: Trust members details by group should be investigated" {

        $result = Test-MtAdGroupMemberTrustDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "trust member details should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
