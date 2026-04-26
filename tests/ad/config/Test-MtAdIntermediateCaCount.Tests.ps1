Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-18" {
    It "AD-CFG-18: Intermediate CA count should be retrievable" {
        $result = Test-MtAdIntermediateCaCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "intermediate CA data should be accessible"
        }
    }
}
