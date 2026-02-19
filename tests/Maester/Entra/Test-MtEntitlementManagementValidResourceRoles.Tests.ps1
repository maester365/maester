Describe "Maester/Entra" -Tag "Governance", "Entra", "AccessPackages" {
    It "MT.1106: Catalog resources must have valid roles (no stale / removed app roles or SPNs). See https://maester.dev/docs/tests/MT.1106" -Tag "MT.1106" {
        $result = Test-MtEntitlementManagementValidResourceRoles
        $result | Should -Be $true -Because "Catalog resources must have valid roles to ensure proper access provisioning. Stale or removed app roles and service principals can cause assignment failures."
    }
}
