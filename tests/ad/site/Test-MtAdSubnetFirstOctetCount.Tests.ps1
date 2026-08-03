Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SUB-08" {
    It "AD-SUB-08: Distinct first octets count should be retrievable" {

        $result = Test-MtAdSubnetFirstOctetCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "subnet data should be accessible"
        }
    }
}
