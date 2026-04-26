Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SUB-02" {
    It "AD-SUB-02: Sites with subnet associations count should be retrievable" {

        $result = Test-MtAdSubnetSiteAssociationCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "site and subnet data should be accessible"
        }
    }
}
