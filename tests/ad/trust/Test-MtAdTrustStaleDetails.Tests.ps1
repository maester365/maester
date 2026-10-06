Describe "Active Directory - Trusts" -Tag "AD", "AD.Trust", "AD-TRUST-07" {
    It "AD-TRUST-07: Trust stale details should be investigated" {

        $result = Test-MtAdTrustStaleDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "stale trust details should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
