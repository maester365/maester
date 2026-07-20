Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-01" {
    It "AD-DNS-01: DNS zone count should be retrievable" {

        $result = Test-MtAdDnsZoneCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS zone data should be accessible"
        }
    }
}
