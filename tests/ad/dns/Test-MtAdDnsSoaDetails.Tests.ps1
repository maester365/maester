Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-10" {
    It "AD-DNS-10: SOA record details should be retrievable" {

        $result = Test-MtAdDnsSoaDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS SOA data should be accessible"
        }
    }
}
