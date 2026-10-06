Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-KRBTGT-02" {
    It "AD-KRBTGT-02: KRBTGT last logon should be investigated" {

        $result = Test-MtAdKrbtgtLastLogon

        if ($null -ne $result) {
            $result | Should -Be $true -Because "KRBTGT account last logon information should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
