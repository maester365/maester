Describe "CIS" -Tag "CIS 3.1.1", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "All", "CIS M365 v4.0.0" {
    It "CIS 3.1.1 (L1) Ensure Microsoft 365 audit log search is Enabled" {

        $result = Test-MtCisAuditLogSearch

        if ($null -ne $result) {
            $result | Should -Be $true -Because "audit log search is enabled."
        }
    }
}