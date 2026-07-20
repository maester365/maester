Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-21" {
    It "AD-USER-21: Known service account details should be retrievable" {
        $result = Test-MtAdUserKnownServiceAccountDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user service account detail data should be accessible"
        }
    }
}
