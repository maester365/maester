Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-16" {
    It "AD-USER-16: User home directory count should be retrievable" {
        $result = Test-MtAdUserHomeDirectoryCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
