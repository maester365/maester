Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-07" {
    It "AD-USER-07: No pre-authentication user count should be retrievable" {
        $result = Test-MtAdUserNoPreAuthCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
