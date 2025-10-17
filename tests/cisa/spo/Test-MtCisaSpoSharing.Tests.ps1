Describe "CISA" -Tag "MS.SHAREPOINT", "MS.SHAREPOINT.1.1", "CISA.MS.SHAREPOINT.1.1", "CISA", "Security" {
    It "CISA.MS.SHAREPOINT.1.1: External sharing for SharePoint SHALL be limited to Existing guests or Only People in your organization." {

        $result = Test-MtCisaSpoSharing

        if ($null -ne $result) {
            $result | Should -Be $true -Because "external sharing is limited."
        }
    }
}
