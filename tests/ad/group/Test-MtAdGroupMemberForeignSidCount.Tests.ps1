Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD-GMC-06" {
    It "AD-GMC-06: Foreign SID principals count should be investigated" {

        $result = Test-MtAdGroupMemberForeignSidCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "foreign SID data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
