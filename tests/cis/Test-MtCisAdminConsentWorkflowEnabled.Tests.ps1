Describe "CIS" -Tag "CIS.M365.5.1.5.2", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.5.1.5.2: Ensure the admin consent workflow is enabled" {

        $result = Test-MtCisAdminConsentWorkflowEnabled

        if ($null -ne $result) {
            $result | Should -Be $true -Because "admin consent workflow is enabled"
        }
    }
}