Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-17" {
    It "AD-DNS-17: Non-standard zone count should be retrievable" {

        $result = Test-MtAdDnsNonStandardZoneCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS zone data should be accessible"
        }
    }
}
