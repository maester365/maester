Describe "CIS" -Tag "CIS 1.3.6", "L2", "CIS E5 Level 2", "CIS E5", "CIS", "Security", "All", "CIS M365 v3.1.0" {
    It "CIS 1.3.6 (L2) Ensure the customer lockbox feature is enabled" {

        $result = Test-MtCisCustomerLockBox

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the customer lockbox feature is enabled."
        }
    }
}