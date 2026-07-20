Describe "Active Directory - Organizational Units" -Tag "AD", "AD.OU", "AD-OU-02" {
    It "AD-OU-02: OU at domain root count should be retrievable" {

        $result = Test-MtAdOuAtDomainRootCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "OU data should be accessible to analyze root-level OUs"
        }
    }
}
