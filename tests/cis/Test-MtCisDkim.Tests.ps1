Describe "CIS" -Tag "CIS 2.1.9", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "All", "CIS M365 v3.1.0" {
    It "CIS 2.1.9 (L1) Ensure that DKIM is enabled for all Exchange Online Domains" {

        $result = Test-MtCisDkim

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DKIM record should exist and be configured."
        }
    }
}