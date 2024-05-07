BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.4", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.3.4: The Authentication Methods Manage Migration feature SHALL be set to Migration Complete." {
        Test-MtCisaMethodsMigration | Should -Be $true -Because "the migration to Authentication Methods is complete."
    }
}