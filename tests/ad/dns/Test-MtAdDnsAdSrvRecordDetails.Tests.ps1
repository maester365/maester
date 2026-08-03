Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-12" {
    It "AD-DNS-12: AD DS SRV record details should be retrievable" {

        $result = Test-MtAdDnsAdSrvRecordDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS SRV record data should be accessible"
        }
    }
}
