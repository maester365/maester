Describe "CIS" -Tag "CIS 2.4.4", "L1", "CIS E5 Level 1", "CIS E5", "CIS", "Security", "All", "CIS M365 v4.0.0" {
    It "CIS 2.4.4 (L1) Ensure Zero-hour auto purge for Microsoft Teams is on (Only Checks ZAP is enabled)" {

        $result = Test-MtCisZAP

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the Zero-hour auto purge (ZAP) is enabled"
        }
    }
}