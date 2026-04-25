Describe "CIS" -Tag "CIS.M365.6.5.3", "L2", "CIS E3 Level 2", "CIS E3", "CIS E5 Level 2", "CIS E5", "CIS", "Security", "CIS M365 v6.0.1" {
    It "CIS.M365.6.5.3: Ensure additional storage providers are restricted in Outlook on the web" {

        $result = Test-MtCisExoAdditionalStorageProvider

        if ($null -ne $result) {
            $result | Should -Be $true -Because 'AdditionalStorageProvidersAvailable should be False'
        }
    }
}
