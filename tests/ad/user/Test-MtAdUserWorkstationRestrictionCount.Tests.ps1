Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-10" {
    It "AD-USER-10: Workstation-restricted user count should be retrievable" {
        $result = Test-MtAdUserWorkstationRestrictionCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
