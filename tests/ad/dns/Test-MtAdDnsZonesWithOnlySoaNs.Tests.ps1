Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-02" {
    It "AD-DNS-02: Zones with only SOA/NS records should be retrievable" {

        $result = Test-MtAdDnsZonesWithOnlySoaNs

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS zone data should be accessible"
        }
    }
}
