Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD.GMC", "AD-GMC-11" {
    It "AD-GMC-11: Privileged groups with members details should be investigated" {

        $result = Test-MtAdGroupPrivilegedWithMembersDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "privileged group member details should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
