Describe "Active Directory - Password Policy" -Tag "AD", "AD.PasswordPolicy", "AD-PWDPOL-04" {
    It "AD-PWDPOL-04: Password complexity requirement should be retrievable" {

        $result = Test-MtAdPasswordComplexityRequired

        if ($null -ne $result) {
            $result | Should -Be $true -Because "password policy data should be accessible"
        }
    }
}
