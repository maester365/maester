Describe "CIS" -Tag "CIS 2.1.1", "L2", "CIS E5 Level 2", "CIS E5", "CIS", "Security", "All", "CIS M365 v3.1.0" {
    It "2.1.1 (L2) Ensure Safe Links for Office Applications is Enabled (Only Checks Default Policy)" {

        $result = Test-MtCisSafeLink

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the default safe link policy matches CIS recommendations"
        }
    }
}