BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.9", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.7.9: User activation of other highly privileged roles SHOULD trigger an alert." {
        Test-MtCisaActivationNotification -GlobalAdminOnly | Should -Be $true -Because "notifications are set for activation of highly privileged roles."
    }
}