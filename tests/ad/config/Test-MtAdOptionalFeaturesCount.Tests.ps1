Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-04" {
    It "AD-CFG-04: Optional features count should be retrievable" {
        $result = Test-MtAdOptionalFeaturesCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "optional features data should be accessible"
        }
    }
}
