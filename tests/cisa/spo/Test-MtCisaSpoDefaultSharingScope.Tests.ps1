Describe "CISA" -Tag "MS.SHAREPOINT", "MS.SHAREPOINT.2.1", "CISA.MS.SHAREPOINT.2.1", "CISA" {
    It "CISA.MS.SHAREPOINT.2.1: File and folder default sharing scope SHALL be set to Specific people." {

        $result = Test-MtCisaSpoDefaultSharingScope

        if ($null -ne $result) {
            $result | Should -Be $true -Because "default sharing scope is Specific people."
        }
    }
}
