Describe "CIS" -Tag "CIS.M365.2.1.13", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.2.1.13: (L1) Ensure the connection filter safe list is off (Only Checks Default Policy)" {

        $result = Test-MtCisConnectionFilterSafeList

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the connection filter safe list not enabled."
        }
    }
}
