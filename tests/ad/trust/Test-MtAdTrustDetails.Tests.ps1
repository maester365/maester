Describe "Active Directory - Trusts" -Tag "AD", "AD.Trust", "AD-TRUST-05" {
    It "AD-TRUST-05: Trust configuration details should be retrievable" {

        $result = Test-MtAdTrustDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "trust configuration details should be accessible"
        }
    }
}
