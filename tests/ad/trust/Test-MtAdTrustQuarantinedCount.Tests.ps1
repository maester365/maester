Describe "Active Directory - Trusts" -Tag "AD", "AD.Trust", "AD-TRUST-03" {
    It "AD-TRUST-03: Trust quarantined count should be retrievable" {

        $result = Test-MtAdTrustQuarantinedCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "quarantined trust data should be accessible"
        }
    }
}
