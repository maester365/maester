Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-DCOMP-09" {
    It "AD-DCOMP-09: Computer DNS zone details should be retrievable" {

        $result = Test-MtAdComputerDnsZoneDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer DNS zone details should be accessible"
        }
    }
}
