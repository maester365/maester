BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.2.1", "CISA", "Security", "All" -Skip:( $EntraIDPlan -ne "P2" ){
    It "MS.AAD.2.1: Users detected as high risk SHALL be blocked." {
        Test-MtCisaBlockHighRiskUser | Should -Be $true -Because "an enabled policy for all users blocking high risk users shall exist."
    }
}