Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-14" {
    It "AD-USER-14: User SPN count should be retrievable" {
        $result = Test-MtAdUserSpnSetCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
