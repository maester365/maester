BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.7", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.3.7: Managed devices SHOULD be required for authentication." {
        $result = Test-MtCisaManagedDevice
        if($result){
            $result | Should -Be $true -Because "a policy requires compliant or domain joined devices."
        }else{
            Test-MtCisaManagedDevice -SkipHybridJoinCheck | Should -Be $true -Because "a policy requires compliant devices."
        }
    }
}