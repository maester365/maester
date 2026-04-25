Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-06" {
    It "AD-DNS-06: Zones with non-default records should be retrievable" {

        $result = Test-MtAdDnsZonesWithRecordsCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS zone data should be accessible"
        }
    }
}
