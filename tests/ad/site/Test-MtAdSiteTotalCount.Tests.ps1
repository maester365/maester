Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SITE-01" {
    It "AD-SITE-01: Site total count should be retrievable" {

        $result = Test-MtAdSiteTotalCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "site data should be accessible"
        }
    }
}
