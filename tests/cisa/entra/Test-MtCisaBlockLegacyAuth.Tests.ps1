BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.1.1", "CISA", "Security", "All", "MS.AAD" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.1.1: Legacy authentication SHALL be blocked." {
        Test-MtCisaBlockLegacyAuth | Should -Be $true -Because "an enabled policy for all users blocking legacy auth access shall exist."
    }
}