Describe "CIS" -Tag "CIS 2.1.13", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "All", "CIS M365 v4.0.0" {
    It "CIS 2.1.13 (L1) Ensure the connection filter safe list is off (Only Checks Default Policy)" {

        $result = Test-MtCisConnectionFilterSafeList

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the connection filter safe list not enabled."
        }
    }
}