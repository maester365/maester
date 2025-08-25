Describe "CIS" -Tag "CIS.M365.2.1.2", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.2.1.2: (L1) Ensure the Common Attachment Types Filter is enabled (Only Checks Default Policy)" {

        $result = Test-MtCisAttachmentFilter

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the default malware filter policy has the common attachment file filter is enabled."
        }
    }
}
