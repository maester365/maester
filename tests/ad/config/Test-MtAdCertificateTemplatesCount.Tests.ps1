Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-13" {
    It "AD-CFG-13: Certificate templates count should be retrievable" {
        $result = Test-MtAdCertificateTemplatesCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "certificate template data should be accessible"
        }
    }
}
