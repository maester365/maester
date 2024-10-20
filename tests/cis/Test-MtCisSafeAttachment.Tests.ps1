Describe "CIS" -Tag "CIS 2.1.4", "L2", "CIS E5 Level 2", "CIS E5", "CIS", "Security", "All", "CIS M365 v3.1.0" {
    It "2.1.4 (L2) Ensure Safe Attachments policy is enabled (Only Checks Default Policy)" {

        $result = Test-MtCisSafeAttachment

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the default Safe Attachement policy matches CIS recommendations."
        }
    }
}