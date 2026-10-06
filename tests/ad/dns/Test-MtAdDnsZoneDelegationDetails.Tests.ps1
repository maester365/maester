Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-09" {
    It "AD-DNS-09: Zone delegation details should be retrievable" {

        $result = Test-MtAdDnsZoneDelegationDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS delegation data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
