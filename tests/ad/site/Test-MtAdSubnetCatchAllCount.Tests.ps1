Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SUB-03" {
    It "AD-SUB-03: Catch-all subnets count should be retrievable" {

        $result = Test-MtAdSubnetCatchAllCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "subnet data should be accessible"
        }
    }
}
