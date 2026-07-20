Describe "Active Directory - Domain Controllers" -Tag "AD", "AD.DomainController", "AD-DCD-04" {
    It "AD-DCD-04: Non-Global Catalog DC count should be retrievable" {

        $result = Test-MtAdDcNonGlobalCatalogCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Global Catalog configuration data should be accessible"
        }
    }
}
