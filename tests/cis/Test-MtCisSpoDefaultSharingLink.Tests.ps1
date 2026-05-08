Describe "CIS" -Tag "CIS.M365.7.2.7", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS",  "CIS M365 v6.0.1" {
    It "CIS.M365.7.2.7: Ensure link sharing is restricted in SharePoint and OneDrive" {

        $result = Test-MtCisSpoDefaultSharingLink

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Link sharing is restricted in SharePoint and OneDrive"
        }
    }
}
