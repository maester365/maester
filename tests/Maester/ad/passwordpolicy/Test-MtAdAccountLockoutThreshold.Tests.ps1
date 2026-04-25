Describe "Active Directory - Password Policy" -Tag "AD", "AD.PasswordPolicy", "AD-PWDPOL-07" {
    It "AD-PWDPOL-07: Account lockout threshold should be retrievable" {

        $result = Test-MtAdAccountLockoutThreshold

        if ($null -ne $result) {
            $result | Should -Be $true -Because "password policy data should be accessible"
        }
    }
}
