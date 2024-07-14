BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.2.3", "CISA", "Security", "All" -Skip:( $EntraIDPlan -ne "P2" ){
    It "MS.AAD.2.3: Sign-ins detected as high risk SHALL be blocked." {
        Test-MtCisaBlockHighRiskSignIn | Should -Be $true -Because "an enabled policy for all users blocking high risk sign-ins shall exist."
    }
}