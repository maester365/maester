Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-12" {
    It "AD-CFG-12: Enterprise CA count should be retrievable" {
        $result = Test-MtAdEnterpriseCaCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "enterprise CA data should be accessible"
        }
    }
}
