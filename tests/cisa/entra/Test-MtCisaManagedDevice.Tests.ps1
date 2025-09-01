Describe "CISA" -Tag "MS.AAD", "MS.AAD.3.7", "CISA.MS.AAD.3.7", "CISA", "Security", "Entra ID P1" {
    It "CISA.MS.AAD.3.7: Managed devices SHOULD be required for authentication." {
        $result = Test-MtCisaManagedDevice

        if ($null -ne $result) {
            if($result){
                $result | Should -Be $true -Because "a policy requires compliant or domain joined devices."
            }else{
                Test-MtCisaManagedDevice -SkipHybridJoinCheck | Should -Be $true -Because "a policy requires compliant devices."
            }
        }
    }
}
