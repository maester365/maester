Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-KRBTGT-01" {
    It "AD-KRBTGT-01: KRBTGT password age should not exceed 180 days" {

        $result = Test-MtAdKrbtgtPasswordLastSet

        if ($null -ne $result) {
            $result | Should -Be $true -Because "old KRBTGT passwords prolong exposure after key material theft"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
