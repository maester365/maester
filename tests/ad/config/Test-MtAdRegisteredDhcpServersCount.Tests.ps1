Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-11" {
    It "AD-CFG-11: Registered DHCP servers count should be retrievable" {
        $result = Test-MtAdRegisteredDhcpServersCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "registered DHCP server data should be accessible"
        }
    }
}
