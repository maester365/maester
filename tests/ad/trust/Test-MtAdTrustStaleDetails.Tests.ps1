Describe "Active Directory - Trusts" -Tag "AD", "AD.Trust", "AD-TRUST-07" {
    It "AD-TRUST-07: Trust stale details should be retrievable" {

        $result = Test-MtAdTrustStaleDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "stale trust details should be accessible"
        }
    }
}
