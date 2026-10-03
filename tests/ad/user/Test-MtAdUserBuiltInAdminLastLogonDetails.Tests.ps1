Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-24" {
    It "AD-USER-24: Built-in administrator last logon details should be investigated" {
        $result = Test-MtAdUserBuiltInAdminLastLogonDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "built-in administrator last logon data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
