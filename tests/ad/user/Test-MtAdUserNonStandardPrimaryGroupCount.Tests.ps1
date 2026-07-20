Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-12" {
    It "AD-USER-12: User non-standard primary group count should be retrievable" {
        $result = Test-MtAdUserNonStandardPrimaryGroupCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
