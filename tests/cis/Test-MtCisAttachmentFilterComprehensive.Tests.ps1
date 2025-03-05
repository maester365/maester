Describe "CIS" -Tag "CIS 2.1.14", "L2", "CIS E3 Level 2", "CIS E3", "CIS", "Security", "All", "CIS M365 v3.1.0" {
    It "CIS 2.1.14 (L2) Ensure comprehensive attachment filtering is applied" {

        $result = Test-MtCisAttachmentFilterComprehensive

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the default malware filter policy did not have comprehensive attachment filtering applied."
        }
    }
}