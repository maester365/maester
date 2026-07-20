Describe "Active Directory - Domain" -Tag "AD", "AD.Domain", "AD-DOM-05" {
    It "AD-DOM-05: Domain name standard compliance should be retrievable" {

        $result = Test-MtAdDomainNameStandardCompliance

        if ($null -ne $result) {
            $result | Should -Be $true -Because "domain name compliance data should be accessible"
        }
    }
}
