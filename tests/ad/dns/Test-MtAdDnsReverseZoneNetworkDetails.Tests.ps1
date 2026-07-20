Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-19" {
    It "AD-DNS-19: Reverse zone network details should be retrievable" {

        $result = Test-MtAdDnsReverseZoneNetworkDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS zone data should be accessible"
        }
    }
}
