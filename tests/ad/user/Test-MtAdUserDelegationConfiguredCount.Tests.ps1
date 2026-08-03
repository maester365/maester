Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-28" {
    It "AD-USER-28: User delegation configured count should be retrievable" {
        $result = Test-MtAdUserDelegationConfiguredCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user delegation count data should be accessible"
        }
    }
}
