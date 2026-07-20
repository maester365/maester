Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-20" {
    It "AD-USER-20: Known service account count should be retrievable" {
        $result = Test-MtAdUserKnownServiceAccountCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
