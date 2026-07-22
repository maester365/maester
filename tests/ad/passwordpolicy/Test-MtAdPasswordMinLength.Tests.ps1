Describe "Active Directory - Password Policy" -Tag "AD", "AD.PasswordPolicy", "AD-PWDPOL-03" {
    It "AD-PWDPOL-03: Password minimum length should be retrievable" {

        $result = Test-MtAdPasswordMinLength

        if ($null -ne $result) {
            $result | Should -Be $true -Because "password policy data should be accessible"
        }
    }
}
