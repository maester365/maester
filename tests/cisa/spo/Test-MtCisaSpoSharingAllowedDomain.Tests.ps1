Describe "CISA" -Tag "MS.SHAREPOINT", "MS.SHAREPOINT.1.3", "CISA.MS.SHAREPOINT.1.3", "CISA", "Security" {
    It "CISA.MS.SHAREPOINT.1.3: External sharing SHALL be restricted to approved external domains and/or users in approved security groups per interagency collaboration needs." {

        $result = Test-MtCisaSpoSharingAllowedDomain

        if ($null -ne $result) {
            $result | Should -Be $true -Because "external sharing is limited."
        }
    }
}
