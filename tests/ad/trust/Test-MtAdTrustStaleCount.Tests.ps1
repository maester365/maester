Describe "Active Directory - Trusts" -Tag "AD", "AD.Trust", "AD-TRUST-06" {
    It "AD-TRUST-06: Trust stale count should be retrievable" {

        $result = Test-MtAdTrustStaleCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "stale trust data should be accessible"
        }
    }
}
