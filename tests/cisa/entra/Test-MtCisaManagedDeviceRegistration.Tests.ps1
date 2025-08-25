Describe "CISA" -Tag "MS.AAD", "MS.AAD.3.8", "CISA.MS.AAD.3.8", "CISA", "Security", "Entra ID P1" {
    It "CISA.MS.AAD.3.8: Managed Devices SHOULD be required to register MFA." {
        $result = Test-MtCisaManagedDeviceRegistration

        if ($null -ne $result) {
            if($result){
                $result | Should -Be $true -Because "a policy requires compliant or domain joined devices for registration."
            }else{
                Test-MtCisaManagedDeviceRegistration -SkipHybridJoinCheck | Should -Be $true -Because "a policy requires compliant devices for registration."
            }
        }
    }
}
