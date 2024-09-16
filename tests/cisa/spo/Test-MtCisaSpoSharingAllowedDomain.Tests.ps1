Describe "CISA SCuBA" -Tag "MS.SHAREPOINT", "MS.SHAREPOINT.1.3", "CISA", "Security", "All" {
    It "MS.SHAREPOINT.1.3: External sharing SHALL be restricted to approved external domains and/or users in approved security groups per interagency collaboration needs." {

        $result = Test-MtCisaSharePointOnlineSharingAllowedDomain

        if ($null -ne $result) {
            $result | Should -Be $true -Because "external sharing is limited."
        }
    }
}