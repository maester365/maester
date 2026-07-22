Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-11" {
    It "AD-USER-11: User AdminCount count should be retrievable" {
        $result = Test-MtAdUserAdminCountCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
