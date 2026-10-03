Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-07" {
    It "AD-DNS-07: Zone record count details should be retrievable" {

        $result = Test-MtAdDnsZoneRecordDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS zone data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
