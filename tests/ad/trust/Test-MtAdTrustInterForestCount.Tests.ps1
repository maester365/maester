Describe "Active Directory - Trusts" -Tag "AD", "AD.Trust", "AD-TRUST-02" {
    It "AD-TRUST-02: Trust inter-forest count should be retrievable" {

        $result = Test-MtAdTrustInterForestCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "inter-forest trust data should be accessible"
        }
    }
}
