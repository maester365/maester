Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-14" {
    It "AD-DNS-14: Empty zone count should be retrievable" {

        $result = Test-MtAdDnsEmptyZoneCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS zone data should be accessible"
        }
    }
}
