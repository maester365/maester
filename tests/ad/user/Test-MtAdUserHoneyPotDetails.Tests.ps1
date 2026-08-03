Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-27" {
    It "AD-USER-27: Honey pot user details should be retrievable" {
        $result = Test-MtAdUserHoneyPotDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "potential honey pot user detail data should be accessible"
        }
    }
}
