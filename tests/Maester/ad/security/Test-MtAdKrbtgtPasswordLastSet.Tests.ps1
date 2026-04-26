Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-KRBTGT-01" {
    It "AD-KRBTGT-01: KRBTGT password last set should be retrievable" {

        $result = Test-MtAdKrbtgtPasswordLastSet

        if ($null -ne $result) {
            $result | Should -Be $true -Because "KRBTGT account password information should be accessible"
        }
    }
}
