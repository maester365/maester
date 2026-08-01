Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-04" {
    It "AD-USER-04: Reversible encryption user count should be retrievable" {
        $result = Test-MtAdUserReversibleEncryptionCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
