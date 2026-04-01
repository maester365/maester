Describe "Maester/Entra" -Tag "Governance", "Entra", "AccessPackages" {
    It "MT.1107: Access packages and catalogs should not reference deleted groups. See https://maester.dev/docs/tests/MT.1107" -Tag "MT.1107" {
        $result = Test-MtEntitlementManagementDeletedGroups
        $result | Should -Be $true -Because "Access packages and catalogs should not reference deleted groups to prevent access provisioning failures and configuration inconsistencies."
    }
}
