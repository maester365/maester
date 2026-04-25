Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-03" {
    It "AD-DNS-03: Root servers with incorrect IPs should be retrievable" {

        $result = Test-MtAdDnsRootServerIncorrectCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS root server data should be accessible"
        }
    }
}
