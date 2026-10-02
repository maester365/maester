Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-DCOMP-09" {
    It "AD-DCOMP-09: Computer DNS zone details should be investigated" {

        $result = Test-MtAdComputerDnsZoneDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer DNS zone details should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
