Describe "CISA SCuBA" -Tag "MS.SHAREPOINT", "MS.SHAREPOINT.1.1", "CISA", "Security", "All" {
    It "MS.SHAREPOINT.1.1: External sharing for SharePoint SHALL be limited to Existing guests or Only People in your organization." {

        $result = Test-MtCisaSharePointOnlineSharing

        if ($null -ne $result) {
            $result | Should -Be $true -Because "external sharing is limited."
        }
    }
}