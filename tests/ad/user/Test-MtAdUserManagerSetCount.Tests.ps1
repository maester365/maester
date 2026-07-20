Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-15" {
    It "AD-USER-15: User manager count should be retrievable" {
        $result = Test-MtAdUserManagerSetCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
