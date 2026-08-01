Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-DCOMP-07" {
    It "AD-DCOMP-07: Computer DNS host name count should be retrievable" {

        $result = Test-MtAdComputerDnsHostNameCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer DNS host name information should be accessible"
        }
    }
}
