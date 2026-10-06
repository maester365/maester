Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-23" {
    It "AD-USER-23: Enabled built-in administrator details should be investigated" {
        $result = Test-MtAdUserBuiltInAdminEnabledDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "enabled built-in administrator detail data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
