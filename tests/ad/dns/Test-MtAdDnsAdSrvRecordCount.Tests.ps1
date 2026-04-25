Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-11" {
    It "AD-DNS-11: AD DS SRV record count should be retrievable" {

        $result = Test-MtAdDnsAdSrvRecordCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS SRV record data should be accessible"
        }
    }
}
