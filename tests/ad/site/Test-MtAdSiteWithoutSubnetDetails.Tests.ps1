Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SITE-05" {
    It "AD-SITE-05: Sites without subnet associations details should be retrievable" {

        $result = Test-MtAdSiteWithoutSubnetDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "site and subnet data should be accessible"
        }
    }
}
