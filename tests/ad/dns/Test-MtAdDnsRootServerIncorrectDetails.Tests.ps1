Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-04" {
    It "AD-DNS-04: Root server incorrect IP details should be retrievable" {

        $result = Test-MtAdDnsRootServerIncorrectDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS root server data should be accessible"
        }
    }
}
