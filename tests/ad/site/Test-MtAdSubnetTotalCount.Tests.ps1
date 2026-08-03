Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SUB-01" {
    It "AD-SUB-01: Subnet total count should be retrievable" {

        $result = Test-MtAdSubnetTotalCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "subnet data should be accessible"
        }
    }
}
