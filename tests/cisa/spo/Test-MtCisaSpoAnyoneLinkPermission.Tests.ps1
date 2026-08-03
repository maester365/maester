Describe "CISA" -Tag "MS.SHAREPOINT", "MS.SHAREPOINT.3.2", "CISA.MS.SHAREPOINT.3.2", "CISA" {
    It "CISA.MS.SHAREPOINT.3.2: Allowable file and folder permissions for Anyone links SHALL be set to View only." {

        $result = Test-MtCisaSpoAnyoneLinkPermission

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Anyone link permissions are View only."
        }
    }
}
