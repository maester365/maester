Describe "CISA" -Tag "MS.SHAREPOINT", "MS.SHAREPOINT.2.2", "CISA.MS.SHAREPOINT.2.2", "CISA" {
    It "CISA.MS.SHAREPOINT.2.2: File and folder default sharing permissions SHALL be set to view only." {

        $result = Test-MtCisaSpoDefaultSharingPermission

        if ($null -ne $result) {
            $result | Should -Be $true -Because "default sharing permissions are view only."
        }
    }
}
