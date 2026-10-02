Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-22" {
    It "AD-USER-22: Built-in administrator account count should be investigated" {
        $result = Test-MtAdUserBuiltInAdminCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "built-in administrator count data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
