Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-16" {
    It "AD-CFG-16: Trusted root CA count should be retrievable" {
        $result = Test-MtAdTrustedRootCaCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "trusted root CA data should be accessible"
        }
    }
}
