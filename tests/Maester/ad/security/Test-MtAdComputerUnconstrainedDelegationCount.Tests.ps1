Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-DCOMP-01" {
    It "AD-DCOMP-01: Computers with unconstrained delegation count should be retrievable" {

        $result = Test-MtAdComputerUnconstrainedDelegationCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer unconstrained delegation information should be accessible"
        }
    }
}
