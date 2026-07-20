Describe "Active Directory - Trusts" -Tag "AD", "AD.Trust", "AD-TRUST-04" {
    It "AD-TRUST-04: Trust non-quarantined details should be retrievable" {

        $result = Test-MtAdTrustNonQuarantinedDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "non-quarantined trust details should be accessible"
        }
    }
}
