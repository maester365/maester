Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-08" {
    It "AD-USER-08: Never-logged-in enabled user count should be retrievable" {
        $result = Test-MtAdUserNeverLoggedInCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
