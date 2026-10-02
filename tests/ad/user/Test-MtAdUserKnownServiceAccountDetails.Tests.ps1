Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-21" {
    It "AD-USER-21: Known service account details should be investigated" {
        $result = Test-MtAdUserKnownServiceAccountDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user service account detail data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
