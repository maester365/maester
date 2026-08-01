Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SUB-11" {
    It "AD-SUB-11: Subnets without site associations count should be retrievable" {

        $result = Test-MtAdSubnetWithoutSiteCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "subnet data should be accessible"
        }
    }
}
