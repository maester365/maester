Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-15" {
    It "AD-CFG-15: Enrollment CA certificate details should be retrievable" {
        $result = Test-MtAdEnrollmentCaCertificateDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "enrollment CA certificate data should be accessible"
        }
    }
}
