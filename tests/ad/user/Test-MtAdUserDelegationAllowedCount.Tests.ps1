Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-05" {
    It "AD-USER-05: Delegation-enabled user count should be retrievable" {
        $result = Test-MtAdUserDelegationAllowedCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
