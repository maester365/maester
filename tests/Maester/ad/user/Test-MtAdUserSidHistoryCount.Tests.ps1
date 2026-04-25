Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-13" {
    It "AD-USER-13: User SID History count should be retrievable" {
        $result = Test-MtAdUserSidHistoryCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
