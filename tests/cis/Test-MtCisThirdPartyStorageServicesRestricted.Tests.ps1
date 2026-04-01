Describe "CIS" -Tag "CIS.M365.1.3.7", "L2", "CIS E3 Level 2", "CIS E3", "CIS E5 Level 2", "CIS E5", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.1.3.7: Ensure 'third-party storage services' are restricted in 'Microsoft 365 on the web'" {

        $result = Test-MtCisThirdPartyStorageServicesRestricted

        if ($null -ne $result) {
            $result | Should -Be $true -Because "third-party storage services are restricted."
        }
    }
}