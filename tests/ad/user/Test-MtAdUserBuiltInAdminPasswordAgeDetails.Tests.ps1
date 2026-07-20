Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-25" {
    It "AD-USER-25: Built-in administrator password age details should be retrievable" {
        $result = Test-MtAdUserBuiltInAdminPasswordAgeDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "built-in administrator password age data should be accessible"
        }
    }
}
