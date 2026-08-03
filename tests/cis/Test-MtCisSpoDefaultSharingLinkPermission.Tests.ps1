Describe "CIS" -Tag "SharePoint Online", "OneDrive", "CIS.M365.7.2.11", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS", "CIS M365 v6.0.1" {
    It "CIS.M365.7.2.11: Ensure the SharePoint default sharing link permission is set" {

        $result = Test-MtCisSpoDefaultSharingLinkPermission

        if ($null -ne $result) {
            $result | Should -Be $true -Because "The SharePoint default sharing link permission is set"
        }
    }
}
