Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-19" {
    It "AD-CFG-19: Intermediate CA details should be retrievable" {
        $result = Test-MtAdIntermediateCaDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "intermediate CA details should be accessible"
        }
    }
}
