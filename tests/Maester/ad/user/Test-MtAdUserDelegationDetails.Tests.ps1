Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-29" {
    It "AD-USER-29: User delegation details should be retrievable" {
        $result = Test-MtAdUserDelegationDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user delegation detail data should be accessible"
        }
    }
}
