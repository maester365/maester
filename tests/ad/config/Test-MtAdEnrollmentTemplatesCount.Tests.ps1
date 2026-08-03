Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-14" {
    It "AD-CFG-14: Enrollment templates count should be retrievable" {
        $result = Test-MtAdEnrollmentTemplatesCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "enrollment template data should be accessible"
        }
    }
}
