Describe "CISA" -Tag "MS.SHAREPOINT", "MS.SHAREPOINT.1.2", "CISA.MS.SHAREPOINT.1.2", "CISA" {
    It "CISA.MS.SHAREPOINT.1.2: External sharing for OneDrive SHALL be limited to Existing guests or Only people in your organization." {

        $result = Test-MtCisaSpoOneDriveSharing

        if ($null -ne $result) {
            $result | Should -Be $true -Because "OneDrive external sharing is limited."
        }
    }
}
