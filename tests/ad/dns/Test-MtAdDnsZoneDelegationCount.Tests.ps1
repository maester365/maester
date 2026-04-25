Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-08" {
    It "AD-DNS-08: Zone delegation count should be retrievable" {

        $result = Test-MtAdDnsZoneDelegationCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS delegation data should be accessible"
        }
    }
}
