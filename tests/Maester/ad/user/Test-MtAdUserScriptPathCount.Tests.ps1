Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-18" {
    It "AD-USER-18: User script path count should be retrievable" {
        $result = Test-MtAdUserScriptPathCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
