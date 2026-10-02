Describe "Active Directory - DNS Infrastructure" -Tag "AD", "AD.DNS", "AD-DNS-05" {
    It "AD-DNS-05: Dynamic DNS record count should be retrievable" {

        $result = Test-MtAdDnsDynamicRecordCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DNS record data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
