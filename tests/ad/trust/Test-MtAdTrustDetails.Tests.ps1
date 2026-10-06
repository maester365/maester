Describe "Active Directory - Trusts" -Tag "AD", "AD.Trust", "AD-TRUST-05" {
    It "AD-TRUST-05: Trust configuration details should be investigated" {

        $result = Test-MtAdTrustDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "trust configuration details should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
