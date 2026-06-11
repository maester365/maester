Describe "CIS" -Tag "SharePoint Online", "OneDrive", "CIS.M365.7.2.2", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS", "CIS M365 v6.0.1" {
    It "CIS.M365.7.2.2: Ensure SharePoint and OneDrive integration with Azure AD B2B is enabled" {

        $result = Test-MtCisSpoB2BIntegration

        if ($null -ne $result) {
            $result | Should -Be $true -Because "SharePoint and OneDrive integration with Azure AD B2B is enabled"
        }
    }
}
