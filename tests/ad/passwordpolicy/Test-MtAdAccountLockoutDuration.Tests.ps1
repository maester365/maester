Describe "Active Directory - Password Policy" -Tag "AD", "AD.PasswordPolicy", "AD-PWDPOL-06" {
    It "AD-PWDPOL-06: Account lockout duration should be retrievable" {

        $result = Test-MtAdAccountLockoutDuration

        if ($null -ne $result) {
            $result | Should -Be $true -Because "password policy data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
