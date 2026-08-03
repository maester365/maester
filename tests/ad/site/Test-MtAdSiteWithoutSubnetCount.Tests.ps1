Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SITE-04" {
    It "AD-SITE-04: Sites without subnet associations count should be retrievable" {

        $result = Test-MtAdSiteWithoutSubnetCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "site and subnet data should be accessible"
        }
    }
}
