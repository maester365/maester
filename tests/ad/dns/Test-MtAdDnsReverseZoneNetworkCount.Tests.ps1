Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-18" {
    It "AD-DNS-18: Reverse zone network count should be retrievable" {

        $result = Test-MtAdDnsReverseZoneNetworkCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS zone data should be accessible"
        }
    }
}
