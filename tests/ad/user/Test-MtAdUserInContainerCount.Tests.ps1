Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-19" {
    It "AD-USER-19: User in container count should be retrievable" {
        $result = Test-MtAdUserInContainerCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
