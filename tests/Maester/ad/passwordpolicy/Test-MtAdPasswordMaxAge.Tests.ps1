Describe "Active Directory - Password Policy" -Tag "AD", "AD.PasswordPolicy", "AD-PWDPOL-02" {
    It "AD-PWDPOL-02: Password maximum age should be retrievable" {

        $result = Test-MtAdPasswordMaxAge

        if ($null -ne $result) {
            $result | Should -Be $true -Because "password policy data should be accessible"
        }
    }
}
