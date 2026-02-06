Describe "CIS" -Tag "CIS.M365.1.3.5", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.1.3.5:  Ensure internal phishing protection for Forms is enabled" {

        $result = Test-MtCisFormsPhishingProtectionEnabled

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Forms phishing protection is enabled."
        }
    }
}