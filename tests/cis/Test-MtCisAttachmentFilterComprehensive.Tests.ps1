Describe "CIS" -Tag "CIS.M365.2.1.11", "L2", "CIS E3 Level 2", "CIS E3", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.2.1.11: (L2) Ensure comprehensive attachment filtering is applied" {

        $result = Test-MtCisAttachmentFilterComprehensive

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the default malware filter policy did not have comprehensive attachment filtering applied."
        }
    }
}
