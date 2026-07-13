Describe "CISA" -Tag "MS.SHAREPOINT", "MS.SHAREPOINT.3.1", "CISA.MS.SHAREPOINT.3.1", "CISA" {
    It "CISA.MS.SHAREPOINT.3.1: Expiration days for Anyone links SHALL be set to 30 days or less." {

        $result = Test-MtCisaSpoAnyoneLinkExpiration

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Anyone links expire within 30 days."
        }
    }
}
