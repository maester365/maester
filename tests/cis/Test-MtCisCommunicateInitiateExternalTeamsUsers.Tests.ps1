Describe "CIS" -Tag "CIS.M365.8.2.3", "CIS", "CIS M365 v6.0.1" {
    It "CIS.M365.8.2.3: Ensure external Teams users cannot initiate conversations" -Tag "CIS.M365.8.2.3", "CIS E3 Level 1" {

        $result = Test-MtCisCommunicateInitiateExternalTeamsUsers

        if ($null -ne $result) {
            $result | Should -Be $true -Because "External Teams users cannot initiate conversations."
        }
    }
}
