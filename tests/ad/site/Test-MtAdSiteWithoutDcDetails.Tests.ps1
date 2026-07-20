Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SITE-03" {
    It "AD-SITE-03: Sites without domain controllers details should be retrievable" {

        $result = Test-MtAdSiteWithoutDcDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "site and DC data should be accessible"
        }
    }
}
