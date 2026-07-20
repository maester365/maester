Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SITE-02" {
    It "AD-SITE-02: Sites without domain controllers count should be retrievable" {

        $result = Test-MtAdSiteWithoutDcCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "site and DC data should be accessible"
        }
    }
}
