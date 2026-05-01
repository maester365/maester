Describe 'CIS' -Tag 'CIS.M365.1.3.6', 'L2', 'CIS E5 Level 2', 'CIS E5', 'CIS', 'CIS M365 v6.0.1' {
    It "CIS.M365.1.3.6: Ensure the customer lockbox feature is enabled" {

        $result = Test-MtCisCustomerLockBox

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the customer lockbox feature is enabled."
        }
    }
}
