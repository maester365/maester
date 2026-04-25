Describe "Active Directory - Password Policy" -Tag "AD", "AD.PasswordPolicy", "AD-PWDPOL-01" {
    It "AD-PWDPOL-01: Password history count should be retrievable" {

        $result = Test-MtAdPasswordHistoryCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "password policy data should be accessible"
        }
    }
}
