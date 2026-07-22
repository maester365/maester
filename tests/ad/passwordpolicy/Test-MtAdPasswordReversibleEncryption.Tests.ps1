Describe "Active Directory - Password Policy" -Tag "AD", "AD.PasswordPolicy", "AD-PWDPOL-05" {
    It "AD-PWDPOL-05: Password reversible encryption status should be retrievable" {

        $result = Test-MtAdPasswordReversibleEncryption

        if ($null -ne $result) {
            $result | Should -Be $true -Because "password policy data should be accessible"
        }
    }
}
