Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-17" {
    It "AD-USER-17: User profile path count should be retrievable" {
        $result = Test-MtAdUserProfilePathCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
