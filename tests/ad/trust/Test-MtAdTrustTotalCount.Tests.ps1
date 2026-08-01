Describe "Active Directory - Trusts" -Tag "AD", "AD.Trust", "AD-TRUST-01" {
    It "AD-TRUST-01: Trust total count should be retrievable" {

        $result = Test-MtAdTrustTotalCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "trust data should be accessible"
        }
    }
}
