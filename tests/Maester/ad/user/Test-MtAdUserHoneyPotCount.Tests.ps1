Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-26" {
    It "AD-USER-26: Honey pot user count should be retrievable" {
        $result = Test-MtAdUserHoneyPotCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "potential honey pot user count data should be accessible"
        }
    }
}
