Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-15" {
    It "AD-DNS-15: Duplicate zone count should be retrievable" {

        $result = Test-MtAdDnsDuplicateZoneCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS zone data should be accessible"
        }
    }
}
