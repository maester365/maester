Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-DCOMP-08" {
    It "AD-DCOMP-08: Computer DNS zone count should be investigated" {

        $result = Test-MtAdComputerDnsZoneCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer DNS zone information should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
