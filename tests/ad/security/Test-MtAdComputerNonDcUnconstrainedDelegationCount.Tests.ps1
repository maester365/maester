Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-DCOMP-02" {
    It "AD-DCOMP-02: Non-DC computers should not have unconstrained delegation" {

        $result = Test-MtAdComputerNonDcUnconstrainedDelegationCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "non-DC computers with unconstrained delegation represent a critical security risk"
        }
    }
}
