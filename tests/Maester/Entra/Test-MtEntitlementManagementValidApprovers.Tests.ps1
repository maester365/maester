Describe "Maester/Entra" -Tag "Governance", "Entra", "AccessPackages" {
    It "MT.1109: Access package approval workflows must have valid approvers. See https://maester.dev/docs/tests/MT.1109" -Tag "MT.1109" {
        $result = Test-MtEntitlementManagementValidApprovers
        $result | Should -Be $true -Because "Access package approval workflows must have valid approvers to prevent workflow failures and blocked access requests."
    }
}
