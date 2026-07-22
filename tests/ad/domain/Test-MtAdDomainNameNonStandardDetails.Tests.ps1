Describe "Active Directory - Domain" -Tag "AD", "AD.Domain", "AD-DOM-06" {
    It "AD-DOM-06: Domain name non-standard details should be retrievable" {

        $result = Test-MtAdDomainNameNonStandardDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "domain name non-standard details should be accessible"
        }
    }
}
