BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.6", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.7.6:     Activation of the Global Administrator role SHALL require approval." {
        Test-MtCisaRequireActivationApproval | Should -Be $true -Because "the Global Administrator role requires approval for activation."
    }
}