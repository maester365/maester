Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-13" {
    It "AD-DNS-13: DNSSEC record count should be retrievable" {

        $result = Test-MtAdDnsDnssecRecordCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNSSEC data should be accessible"
        }
    }
}
