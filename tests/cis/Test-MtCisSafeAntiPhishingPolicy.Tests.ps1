Describe "CIS" -Tag "CIS 2.1.7", "L1", "CIS E5 Level 1", "CIS E5", "CIS", "Security", "All", "CIS M365 v3.1.0" {
    It "2.1.7 (L1) Ensure that an anti-phishing policy has been created (Only Checks Default Policy)" {

        $result = Test-MtCisSafeAntiPhishingPolicy

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the default anti-phishing policy is enabled."
        }
    }
}