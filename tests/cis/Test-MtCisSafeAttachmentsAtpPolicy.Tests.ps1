Describe "CIS" -Tag "CIS.M365.2.1.5", "L2", "CIS E5 Level 2", "CIS E5", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.2.1.5: (L2) Ensure Safe Attachments for SharePoint, OneDrive, and Microsoft Teams is Enabled" {

        $result = Test-MtCisSafeAttachmentsAtpPolicy

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the Safe Attachement policies for SharePoint, OneDrive, and Microsoft Teams are Enabled."
        }
    }
}
