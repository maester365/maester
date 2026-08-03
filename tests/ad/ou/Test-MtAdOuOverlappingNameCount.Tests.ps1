Describe "Active Directory - Organizational Units" -Tag "AD", "AD.OU", "AD-OU-01" {
    It "AD-OU-01: OU overlapping name count should be retrievable" {

        $result = Test-MtAdOuOverlappingNameCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "OU data should be accessible to analyze for duplicate names"
        }
    }
}
