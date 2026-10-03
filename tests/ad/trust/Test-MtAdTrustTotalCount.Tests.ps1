Describe "Active Directory - Trusts" -Tag "AD", "AD.Trust", "AD-TRUST-01" {
    It "AD-TRUST-01: Trust total count should be investigated" {

        $result = Test-MtAdTrustTotalCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "trust data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
