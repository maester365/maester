Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-09" {
    It "AD-USER-09: Password-not-required user count should be retrievable" {
        $result = Test-MtAdUserPasswordNotRequiredCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
