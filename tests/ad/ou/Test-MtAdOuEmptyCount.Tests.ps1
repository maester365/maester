Describe "Active Directory - Organizational Units" -Tag "AD", "AD.OU", "AD-OU-04" {
    It "AD-OU-04: OU empty count should be retrievable" {

        $result = Test-MtAdOuEmptyCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "OU data should be accessible to identify empty OUs"
        }
    }
}
