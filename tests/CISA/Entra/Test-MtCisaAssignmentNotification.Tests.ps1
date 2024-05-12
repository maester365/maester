BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.7", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.7.7: Eligible and Active highly privileged role assignments SHALL trigger an alert." {
        Test-MtCisaAssignmentNotification | Should -Be $true -Because "highly privileged roles are set to notify on assignment."
    }
}