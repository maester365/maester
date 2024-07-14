BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.2.2", "CISA", "Security", "All" -Skip:( $EntraIDPlan -ne "P2" ) {
    It "MS.AAD.2.2: A notification SHOULD be sent to the administrator when high-risk users are detected." {
        Test-MtCisaNotifyHighRisk | Should -Be $true -Because "an enabled is a recipient of risky user login notifications."
    }
}