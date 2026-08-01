Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-17" {
    It "AD-CFG-17: Trusted root CA details should be retrievable" {
        $result = Test-MtAdTrustedRootCaDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "trusted root CA details should be accessible"
        }
    }
}
