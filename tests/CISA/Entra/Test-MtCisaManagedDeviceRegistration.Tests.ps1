BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.8", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.3.8: Managed Devices SHOULD be required to register MFA." {
        Test-MtCisaManagedDeviceRegistration | Should -Be $true -Because "a policy requires managed devices for registration."
    }
}