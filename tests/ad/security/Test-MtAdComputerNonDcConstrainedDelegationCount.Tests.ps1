Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-DCOMP-03" {
    It "AD-DCOMP-03: Non-DC computers with constrained delegation count should be investigated" {

        $result = Test-MtAdComputerNonDcConstrainedDelegationCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "non-DC computer constrained delegation information should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
