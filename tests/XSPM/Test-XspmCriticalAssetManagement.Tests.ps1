BeforeDiscovery {
    try {
        $DefenderPlan = Get-MtLicenseInformation -Product "DefenderXDR"
    } catch {
        $DefenderPlan = "NotConnected"
    }
}

Describe "Exposure Management" -Tag "Entra", "Graph", "Security", "XSPM" -Skip:( $DefenderPlan -ne "DefenderXDR" ) {
    # Privileged assets, identified by EntraOps and Critical Asset Management, should not be exposed due to weak security configurations.
    It "MT.1085: Pending approvals for Critical Asset Management should not be present. See https://maester.dev/docs/tests/MT.1085" -Tag "MT.1085" {
        Test-MtXspmPendingApprovalCriticalAssetManagement | Should -Be $true -Because "no pending approvals for Critical Asset Management should be present, as pending approvals may lead into limited visibility in Defender XDR and potential security risks if critical assets are not properly identified."
    }
}
