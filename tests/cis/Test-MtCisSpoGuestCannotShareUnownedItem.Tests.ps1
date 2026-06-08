Describe "CIS" -Tag "SharePoint Online", "OneDrive", "CIS.M365.7.2.5", "L2", "CIS E3 Level 2", "CIS E3", "CIS E5 Level 2", "CIS E5", "CIS", "CIS M365 v6.0.1" {
    It "CIS.M365.7.2.5: Ensure that SharePoint guest users cannot share items they don't own" {

        $result = Test-MtCisSpoGuestCannotShareUnownedItem

        if ($null -ne $result) {
            $result | Should -Be $true -Because "SharePoint guest users cannot share items they don't own"
        }
    }
}
