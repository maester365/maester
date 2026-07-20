Describe "Active Directory - Users" -Tag "AD", "AD.User", "AD-USER-06" {
    It "AD-USER-06: DES-only Kerberos user count should be retrievable" {
        $result = Test-MtAdUserKerberosDesOnlyCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user data should be accessible"
        }
    }
}
