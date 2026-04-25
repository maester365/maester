Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SUB-04" {
    It "AD-SUB-04: IPv6 subnets count should be retrievable" {

        $result = Test-MtAdSubnetIpv6Count

        if ($null -ne $result) {
            $result | Should -Be $true -Because "subnet data should be accessible"
        }
    }
}
