Describe "Maester/Entra" -Tag "Governance", "Entra", "AccessPackages" {
    It "MT.1110: No catalog should contain resources without any associated access packages. See https://maester.dev/docs/tests/MT.1110" -Tag "MT.1110" {
        $result = Test-MtEntitlementManagementOrphanedResources
        $result | Should -Be $true -Because "Catalog resources without associated access packages indicate configuration drift and should be removed to maintain clean governance setup."
    }
}
