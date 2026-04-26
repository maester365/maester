Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-03" {
    It "AD-USER-03: Non-expiring password user count should be retrievable" {
        $result = Test-MtAdUserPasswordNeverExpiresCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
