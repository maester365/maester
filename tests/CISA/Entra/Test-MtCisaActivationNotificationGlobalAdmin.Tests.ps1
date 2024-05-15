BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.8", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.7.8: User activation of the Global Administrator role SHALL trigger an alert." {
        Test-MtCisaActivationNotification -GlobalAdminOnly | Should -Be $true -Because "notifications are set for activation of the Global Admin role."
    }
}