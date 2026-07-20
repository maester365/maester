Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-02" {
    It "AD-USER-02: Dormant enabled user count should be retrievable" {
        $result = Test-MtAdUserDormantEnabledCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
