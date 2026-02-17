Describe "Maester/Entra" -Tag "Governance", "Entra", "AccessPackages" {
    It "MT.1108: Access packages should not reference inactive or orphaned assignment policies. See https://maester.dev/docs/tests/MT.1108" -Tag "MT.1108" {
        $result = Test-MtEntitlementManagementInactivePolicies
        $result | Should -Be $true -Because "Access packages should not have inactive or misconfigured assignment policies that block access requests or break approval workflows."
    }
}
