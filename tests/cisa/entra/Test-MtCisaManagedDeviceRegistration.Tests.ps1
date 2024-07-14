BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.8", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.3.8: Managed Devices SHOULD be required to register MFA." {
        $result = Test-MtCisaManagedDeviceRegistration
        if($result){
            $result | Should -Be $true -Because "a policy requires compliant or domain joined devices for registration."
        }else{
            Test-MtCisaManagedDeviceRegistration -SkipHybridJoinCheck | Should -Be $true -Because "a policy requires compliant devices for registration."
        }
    }
}